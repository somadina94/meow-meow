-- Update gift prices to: 10, 20, 30, 40, 50, 100, 150, 200, 250, 300
UPDATE gifts SET price = CASE 
  WHEN sort_order = 1 THEN 10
  WHEN sort_order = 2 THEN 20
  WHEN sort_order = 3 THEN 30
  WHEN sort_order = 4 THEN 40
  WHEN sort_order = 5 THEN 50
  WHEN sort_order = 6 THEN 100
  WHEN sort_order = 7 THEN 150
  WHEN sort_order = 8 THEN 200
  WHEN sort_order = 9 THEN 250
  WHEN sort_order = 10 THEN 300
  ELSE price
END
WHERE sort_order BETWEEN 1 AND 10;