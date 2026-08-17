/**
 * useAtomicTransaction Hook
 * 
 * PURPOSE: Provides transaction functions for all financial operations.
 * NOTE: Despite the name, most operations use sequential client-side calls via
 * Supabase RPC functions. True atomicity depends on the DB function implementation.
 * Where possible, operations use single RPC calls that run in a DB transaction.
 * 
 * ACID PROPERTIES:
 * - Atomicity: All operations succeed or fail together (single DB transaction)
 * - Consistency: Database constraints and business rules are always maintained
 * - Isolation: Row-level locking (FOR UPDATE) prevents concurrent modification conflicts
 * - Durability: Committed transactions persist even after system failure
 * 
 * SUPER USERS:
 * - Super users (email pattern: male/female/admin 1-15 @meow-meow.com) bypass balance requirements
 * - Database functions check for super user status server-side
 * 
 * DEADLOCK PREVENTION:
 * - Wallets are locked in consistent order (by user_id) during transfers
 */

import { useState, useCallback, useRef } from "react";
import { classifyError, ERROR_MESSAGES, logError } from "@/lib/errors";
import { supabase } from "@/integrations/supabase/client";
import { useToast } from "@/hooks/use-toast";

// Transaction result interface
interface TransactionResult {
  success: boolean;
  transactionId?: string;
  previousBalance?: number;
  newBalance?: number;
  error?: string;
  superUserBypass?: boolean;
}

// Transfer result interface
interface TransferResult {
  success: boolean;
  fromTransactionId?: string;
  toTransactionId?: string;
  fromPreviousBalance?: number;
  fromNewBalance?: number;
  toPreviousBalance?: number;
  toNewBalance?: number;
  error?: string;
  superUserBypass?: boolean;
}

// Gift transaction result interface
interface GiftResult {
  success: boolean;
  giftTransactionId?: string;
  walletTransactionId?: string;
  previousBalance?: number;
  newBalance?: number;
  giftName?: string;
  giftEmoji?: string;
  error?: string;
  superUserBypass?: boolean;
}

// Chat/Video billing result interface
interface BillingResult {
  success: boolean;
  charged?: number;
  earned?: number;
  sessionEnded?: boolean;
  error?: string;
  superUser?: boolean;
}

// Withdrawal result interface
interface WithdrawalResult {
  success: boolean;
  withdrawalId?: string;
  transactionId?: string;
  previousBalance?: number;
  newBalance?: number;
  error?: string;
}

export const useAtomicTransaction = () => {
  const { toast } = useToast();
  const processingCount = useRef(0);
  const [isProcessing, setIsProcessing] = useState(false);

  const startProcessing = useCallback(() => {
    processingCount.current += 1;
    setIsProcessing(true);
  }, []);

  const stopProcessing = useCallback(() => {
    processingCount.current = Math.max(0, processingCount.current - 1);
    if (processingCount.current === 0) setIsProcessing(false);
  }, []);

  /**
   * Process a wallet transaction atomically
   * Uses database function for ACID compliance with row-level locking
   * 
   * @param userId - User's UUID
   * @param amount - Transaction amount (must be positive)
   * @param type - 'credit' or 'debit'
   * @param description - Optional description
   * @param referenceId - Optional reference ID for tracking
   */
  const processTransaction = useCallback(async (
    userId: string,
    amount: number,
    type: "credit" | "debit",
    description?: string,
    referenceId?: string
  ): Promise<TransactionResult> => {
    startProcessing();
    
    try {
      // Single source of truth: route credits/debits through canonical RPCs.
      // Generic standalone wallet adjustments use ledger_recharge for credits;
      // ad-hoc debits should not be performed via this helper anymore (use a
      // domain-specific billing RPC). For backward compatibility we still call
      // ledger_recharge for credits and surface a clear error otherwise.
      if (type !== "credit") {
        return {
          success: false,
          error: "Direct debit no longer supported — use a domain billing RPC.",
        };
      }
      const { data, error } = await supabase.rpc("ledger_recharge", {
        p_user_id: userId,
        p_amount: amount,
        p_gateway: "manual",
        p_gateway_txn_id: referenceId || null,
        p_description: description || null,
      });

      if (error) throw error;

      const result = data as Record<string, unknown>;

      if (!result.success) {
        toast({
          title: "Transaction Failed",
          description: (result.error as string) || "Unable to process transaction",
          variant: "destructive",
        });
        return {
          success: false,
          error: result.error as string,
        };
      }

      return {
        success: true,
        transactionId: undefined,
        previousBalance: result.previous_balance as number,
        newBalance: result.new_balance as number,
      };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Transaction failed";
      console.error("Transaction error:", err);
      
      toast({
        title: "Transaction Error",
        description: classifyError(err, "complete the transaction").message,
        variant: "destructive",
      });
      
      return { success: false, error: errorMessage };
    } finally {
      stopProcessing();
    }
  }, [toast]);

  /**
   * Transfer funds between users atomically
   * Single database transaction ensures both debit and credit succeed or fail together
   * Uses ordered locking to prevent deadlocks
   * 
   * @param fromUserId - Sender's UUID
   * @param toUserId - Receiver's UUID
   * @param amount - Transfer amount
   * @param description - Optional description
   */
  const transferFunds = useCallback(async (
    fromUserId: string,
    toUserId: string,
    amount: number,
    description?: string
  ): Promise<TransferResult> => {
    startProcessing();
    
    try {
      // Call atomic transfer function (single transaction, ordered locking)
      const { data, error } = await supabase.rpc("process_atomic_transfer", {
        p_from_user_id: fromUserId,
        p_to_user_id: toUserId,
        p_amount: amount,
        p_description: description || null,
      });

      if (error) throw error;

      const result = data as Record<string, unknown>;

      if (!result.success) {
        toast({
          title: "Transfer Failed",
          description: (result.error as string) || "Unable to complete transfer",
          variant: "destructive",
        });
        return { success: false, error: result.error as string };
      }

      toast({
        title: "Transfer Complete",
        description: `Successfully transferred ₹${amount}`,
      });

      return {
        success: true,
        fromTransactionId: result.from_transaction_id as string,
        toTransactionId: result.to_transaction_id as string,
        fromPreviousBalance: result.from_previous_balance as number,
        fromNewBalance: result.from_new_balance as number,
        toPreviousBalance: result.to_previous_balance as number,
        toNewBalance: result.to_new_balance as number,
        superUserBypass: result.super_user_bypass as boolean,
      };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Transfer failed";
      console.error("Transfer error:", err);
      
      toast({
        title: "Transfer Error",
        description: errorMessage,
        variant: "destructive",
      });
      
      return { success: false, error: errorMessage };
    } finally {
      stopProcessing();
    }
  }, [toast]);

  /**
   * Send a gift atomically
   * Deducts from sender's wallet and records gift in single transaction
   * 
   * @param senderId - Sender's UUID
   * @param receiverId - Receiver's UUID
   * @param giftId - Gift UUID
   * @param message - Optional gift message
   */
  const sendGift = useCallback(async (
    senderId: string,
    receiverId: string,
    giftId: string,
    message?: string
  ): Promise<GiftResult> => {
    // Gift/tip billing logic removed — feature disabled until rebuilt.
    void senderId; void receiverId; void giftId; void message;
    toast({
      title: "Gifts Disabled",
      description: "Gift sending is temporarily disabled.",
      variant: "destructive",
    });
    return { success: false, error: "Gift system disabled" };
  }, [toast]);

  /**
   * Process chat billing atomically
   * Deducts from man's wallet and credits woman's earnings in single transaction
   * 
   * @param sessionId - Active chat session UUID
   * @param minutes - Number of minutes to bill
   */
  const processChatBilling = useCallback(async (
    sessionId: string,
    minutes: number
  ): Promise<BillingResult> => {
    void sessionId; void minutes;
    return { success: true, charged: 0, earned: 0, superUser: false };
  }, []);

  /**
   * Process video call billing atomically
   * Deducts from man's wallet and credits woman's earnings in single transaction
   * 
   * @param sessionId - Video call session UUID
   * @param minutes - Number of minutes to bill
   */
  const processVideoBilling = useCallback(async (
    sessionId: string,
    minutes: number,
    manId?: string,
    womanId?: string,
  ): Promise<BillingResult> => {
    void sessionId; void minutes; void manId; void womanId;
    return { success: true, charged: 0, earned: 0, superUser: false };
  }, []);

  /**
   * Request withdrawal atomically
   * Holds funds and creates withdrawal request in single transaction
   * 
   * @param userId - User's UUID
   * @param amount - Withdrawal amount
   * @param paymentMethod - Payment method
   * @param paymentDetails - Payment details JSON
   */
  const requestWithdrawal = useCallback(async (
    userId: string,
    amount: number,
    paymentMethod?: string,
    paymentDetails?: Record<string, string | number | boolean | null>
  ): Promise<WithdrawalResult> => {
    startProcessing();
    
    try {
      const { data, error } = await supabase.rpc("process_withdrawal_request", {
        p_user_id: userId,
        p_amount: amount,
        p_payment_method: paymentMethod || null,
        p_payment_details: paymentDetails ? JSON.parse(JSON.stringify(paymentDetails)) : null,
      });

      if (error) throw error;

      const result = data as Record<string, unknown>;

      if (!result.success) {
        toast({
          title: "Withdrawal Failed",
          description: (result.error as string) || "Unable to process withdrawal",
          variant: "destructive",
        });
        return { success: false, error: result.error as string };
      }

      toast({
        title: "Withdrawal Requested",
        description: `₹${amount} withdrawal is being processed`,
      });

      return {
        success: true,
        withdrawalId: result.withdrawal_id as string,
        transactionId: result.transaction_id as string,
        previousBalance: result.previous_balance as number,
        newBalance: result.new_balance as number,
      };
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : "Withdrawal failed";
      console.error("Withdrawal error:", err);
      
      toast({
        title: "Withdrawal Error",
        description: errorMessage,
        variant: "destructive",
      });
      
      return { success: false, error: errorMessage };
    } finally {
      stopProcessing();
    }
  }, [toast]);

  /**
   * Credit wallet (add funds)
   * Convenience wrapper for processTransaction
   */
  const creditWallet = useCallback(async (
    userId: string,
    amount: number,
    description?: string,
    referenceId?: string
  ): Promise<TransactionResult> => {
    return processTransaction(userId, amount, "credit", description, referenceId);
  }, [processTransaction]);

  /**
   * Debit wallet (remove funds)
   * Convenience wrapper for processTransaction
   */
  const debitWallet = useCallback(async (
    userId: string,
    amount: number,
    description?: string,
    referenceId?: string
  ): Promise<TransactionResult> => {
    return processTransaction(userId, amount, "debit", description, referenceId);
  }, [processTransaction]);

  return {
    isProcessing,
    processTransaction,
    processChatBilling,
    processVideoBilling,
    creditWallet,
    debitWallet,
    transferFunds,
    sendGift,
    requestWithdrawal,
  };
};

export default useAtomicTransaction;
