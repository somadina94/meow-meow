-- Update gift prices to follow pattern: 10, 20, 30, 40, then multiples of 50
UPDATE public.gifts SET price = 10 WHERE sort_order = 1;
UPDATE public.gifts SET price = 20 WHERE sort_order = 2;
UPDATE public.gifts SET price = 30 WHERE sort_order = 3;
UPDATE public.gifts SET price = 40 WHERE sort_order = 4;
UPDATE public.gifts SET price = 50 WHERE sort_order = 5;
UPDATE public.gifts SET price = 100 WHERE sort_order = 6;
UPDATE public.gifts SET price = 150 WHERE sort_order = 7;
UPDATE public.gifts SET price = 200 WHERE sort_order = 8;
UPDATE public.gifts SET price = 250 WHERE sort_order = 9;
UPDATE public.gifts SET price = 300 WHERE sort_order = 10;