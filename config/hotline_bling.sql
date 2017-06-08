[check_availability]
SELECT active 
FROM phone_numbers 
WHERE digits = ?
 
[assign_number]
UPDATE phone_numbers
SET active = 1
WHERE digits = ?
