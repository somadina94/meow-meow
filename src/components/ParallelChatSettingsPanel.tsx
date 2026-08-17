import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { useToast } from "@/hooks/use-toast";
import { MessageSquare, Check, Settings2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface ParallelChatSettingsPanelProps {
  currentValue: number;
  onSave: (value: number) => Promise<void>;
  isLoading?: boolean;
}

const ParallelChatSettingsPanel = ({
  currentValue,
  onSave,
  isLoading
}: ParallelChatSettingsPanelProps) => {
  const { toast } = useToast();
  const [selectedValue, setSelectedValue] = useState(currentValue.toString());
  const [isSaving, setIsSaving] = useState(false);

  const handleSave = async () => {
    setIsSaving(true);
    try {
      await onSave(Number(selectedValue));
      toast({
        title: "Settings Saved",
        description: `Maximum parallel chats set to ${selectedValue}`,
      });
    } catch {
      toast({
        title: "Error",
        description: "Failed to save settings",
        variant: "destructive"
      });
    } finally {
      setIsSaving(false);
    }
  };

  const options = [
    { value: "1", label: "1 Chat", description: "Focus on one conversation at a time" },
    { value: "2", label: "2 Chats", description: "Moderate multitasking" },
    { value: "3", label: "3 Chats", description: "Maximum parallel conversations" }
  ];

  const hasChanges = selectedValue !== currentValue.toString();

  return (
    <Card className="border-primary/20">
      <CardHeader className="pb-3">
        <CardTitle className="flex items-center gap-2 text-base">
          <Settings2 className="h-4 w-4 text-primary" />
          Parallel Chat Settings
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <div>
          <Label className="text-sm text-muted-foreground mb-3 block">
            How many chat windows do you want open at once?
          </Label>
          
          <RadioGroup
            value={selectedValue}
            onValueChange={setSelectedValue}
            className="grid grid-cols-3 gap-3"
            disabled={isLoading}
          >
            {options.map((option) => (
              <div key={option.value} className="relative">
                <RadioGroupItem
                  value={option.value}
                  id={`chat-count-${option.value}`}
                  className="peer sr-only"
                />
                <Label
                  htmlFor={`chat-count-${option.value}`}
                  className={cn(
                    "flex flex-col items-center justify-center p-3 rounded-lg border-2 cursor-pointer transition-all text-center",
                    "hover:border-primary/50 hover:bg-primary/5",
                    selectedValue === option.value
                      ? "border-primary bg-primary/10"
                      : "border-border"
                  )}
                >
                  <div className="flex items-center gap-1 mb-1">
                    {Array.from({ length: Number(option.value) }).map((_, i) => (
                      <MessageSquare
                        key={i}
                        className={cn(
                          "h-4 w-4",
                          selectedValue === option.value
                            ? "text-primary"
                            : "text-muted-foreground"
                        )}
                      />
                    ))}
                  </div>
                  <span className="font-semibold text-sm">{option.label}</span>
                  <span className="text-[10px] text-muted-foreground mt-0.5">
                    {option.description}
                  </span>
                  {selectedValue === option.value && (
                    <Check className="absolute top-1.5 right-1.5 h-3.5 w-3.5 text-primary" />
                  )}
                </Label>
              </div>
            ))}
          </RadioGroup>
        </div>

        <Button
          onClick={handleSave}
          disabled={!hasChanges || isSaving || isLoading}
          className="w-full gap-2"
          size="sm"
        >
          {isSaving ? (
            <>Saving...</>
          ) : (
            <>
              <Check className="h-4 w-4" />
              Save Preference
            </>
          )}
        </Button>

        <p className="text-[10px] text-muted-foreground text-center">
          When you reach max chats, oldest chat windows will be replaced by new ones
        </p>
      </CardContent>
    </Card>
  );
};

export default ParallelChatSettingsPanel;
