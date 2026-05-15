#!/bin/bash

# Use the SUPERUSER (postgres) to demolish and rebuild the database
PSQL_RESTORE="psql --username=postgres --dbname=postgres"

# Use your normal user for the actual edits
PSQL="psql --username=freecodecamp --dbname=periodic_table --tuples-only --no-align -c"

echo "=== Wiping and restoring the original database ==="
# 1. Reload the backup as the superuser
$PSQL_RESTORE < original_database.sql

echo "=== Applying database modifications ==="
# 2. Your edits go here


# Start modification logic here...

echo -e "\n~~~ Updating Periodic Table Schema ~~~\n"

# 1. Rename the 'weight' column to 'atomic_mass'
echo "Renaming column: weight -> atomic_mass..."
RENAME_COLUMN_RESULT=$($PSQL "ALTER TABLE properties RENAME COLUMN weight TO atomic_mass;")
echo "$RENAME_COLUMN_RESULT"

# 2. Rename 'melting_point' and 'boiling_point' (Common project requirements)
echo "Renaming melting and boiling point columns..."
$PSQL "ALTER TABLE properties RENAME COLUMN melting_point TO melting_point_celsius;"
$PSQL "ALTER TABLE properties RENAME COLUMN boiling_point TO boiling_point_celsius;"

echo "Setting NOT NULL constraints on temperature columns..."
$PSQL "ALTER TABLE properties ALTER COLUMN melting_point_celsius SET NOT NULL; ALTER TABLE properties ALTER COLUMN boiling_point_celsius SET NOT NULL;"

# 3. Set NOT NULL constraints
echo "Adding NOT NULL constraints..."
$PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass SET NOT NULL;"

echo "Adding UNIQUE constraints to symbol and name..."

# You can combine them into one ALTER TABLE command to be more efficient
$PSQL "ALTER TABLE elements ADD UNIQUE(symbol), ADD UNIQUE(name);"

echo "Setting NOT NULL constraints for symbol and name..."

$PSQL "ALTER TABLE elements ALTER COLUMN symbol SET NOT NULL, ALTER COLUMN name SET NOT NULL;"

echo "Linking properties to elements via foreign key..."

$PSQL "ALTER TABLE properties ADD FOREIGN KEY(atomic_number) REFERENCES elements(atomic_number);"


echo "Creating types table and seeding data..."

$PSQL "CREATE TABLE types(type_id SERIAL PRIMARY KEY, type VARCHAR(20) NOT NULL);"
$PSQL "INSERT INTO types(type) VALUES('nonmetal'), ('metal'), ('metalloid');"

#!/bin/bash
PSQL="psql --username=freecodecamp --dbname=periodic_table --tuples-only --no-align -c"

echo "Adding and populating type_id column..."

# Add column and FK
$PSQL "ALTER TABLE properties ADD COLUMN type_id INT REFERENCES types(type_id);"

# Map data from 'type' to 'type_id'
$PSQL "UPDATE properties SET type_id = 1 WHERE type = 'nonmetal';"
$PSQL "UPDATE properties SET type_id = 2 WHERE type = 'metal';"
$PSQL "UPDATE properties SET type_id = 3 WHERE type = 'metalloid';"

# Set NOT NULL
$PSQL "ALTER TABLE properties ALTER COLUMN type_id SET NOT NULL;"

#!/bin/bash
PSQL="psql --username=freecodecamp --dbname=periodic_table --tuples-only --no-align -c"

echo "Syncing type_id values..."

# Perform the data migration
$PSQL "UPDATE properties SET type_id = (SELECT type_id FROM types WHERE types.type = properties.type);"

# Verify it worked by checking if any type_id is still null
NULL_COUNT=$($PSQL "SELECT COUNT(*) FROM properties WHERE type_id IS NULL;")

if [[ $NULL_COUNT -eq 0 ]]
then
  echo "Migration successful. Dropping old 'type' column..."
  $PSQL "ALTER TABLE properties DROP COLUMN type;"
else
  echo "Error: Some rows failed to sync. Check your data!"
fi

#!/bin/bash
PSQL="psql --username=freecodecamp --dbname=periodic_table --tuples-only --no-align -c"

echo "Capitalizing element symbols..."
$PSQL "UPDATE elements SET symbol = INITCAP(symbol);"

#!/bin/bash
PSQL="psql --username=freecodecamp --dbname=periodic_table --tuples-only --no-align -c"

echo "Cleaning up atomic_mass values..."

# 1. Ensure the type is numeric
$PSQL "ALTER TABLE properties ALTER COLUMN atomic_mass TYPE NUMERIC;"

# 2. Update the column to remove trailing zeros
# This converts to text, trims zeros, and removes the decimal point if it's trailing
$PSQL "UPDATE properties SET atomic_mass = TRIM(TRAILING '0' FROM CAST(atomic_mass AS TEXT))::NUMERIC;"

# 3. Special case: If you have "1.0", the above might leave "1.". 
# To be safe,  use:
$PSQL "UPDATE properties SET atomic_mass = CAST(atomic_mass AS TEXT)::REAL;"

echo "Inserting Fluorine..."

# 1. Insert into elements
$PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES(9, 'F', 'Fluorine');"

# 2. Get the type_id for 'nonmetal' dynamically
NONMETAL_ID=$($PSQL "SELECT type_id FROM types WHERE type='nonmetal';")

# 3. Insert into properties using that ID
$PSQL "INSERT INTO properties(atomic_number, type_id, atomic_mass, melting_point_celsius, boiling_point_celsius) VALUES(9, $NONMETAL_ID, 18.998, -220, -188.1);"

echo "Inserting Neon..."

# Insert into elements first
$PSQL "INSERT INTO elements(atomic_number, symbol, name) VALUES(10, 'Ne', 'Neon');"

# Get the ID for nonmetal dynamically
NONMETAL_ID=$($PSQL "SELECT type_id FROM types WHERE type='nonmetal';")

# Insert into properties using the retrieved ID
$PSQL "INSERT INTO properties(atomic_number, type_id, atomic_mass, melting_point_celsius, boiling_point_celsius) VALUES(10, $NONMETAL_ID, 20.18, -248.6, -246.1);"

PSQL="psql --username=freecodecamp --dbname=periodic_table --tuples-only --no-align -c"

echo "Deleting non-existent element 1000..."

$PSQL "DELETE FROM properties WHERE atomic_number = 1000; DELETE FROM elements WHERE atomic_number = 1000;"

PSQL="psql --username=freecodecamp --dbname=periodic_table --tuples-only --no-align -c"

echo "Removing redundant type column from properties..."
$PSQL "ALTER TABLE properties DROP COLUMN type;"

echo -e "\nDatabase updates complete!"