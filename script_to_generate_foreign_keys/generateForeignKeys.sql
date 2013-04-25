/*
 # Adempiere contribution
 # Author: Carlos Ruiz - globalqss
 # This script generates the alter table commands to create the foreign keys 
 # based on Adempiere Dictionary definition
 # It runs in oracle database - to generate commands for postgresql comment the lines marked with "for oracle"
 # and comment out the lines marked "for postgresql"
 # 
*/

SELECT      'ALTER TABLE '
         || tablename
         || ' ADD (CONSTRAINT '  /* for oracle */
         -- || ' ADD CONSTRAINT '  /* for postgresql */
         || SUBSTR (   REPLACE (SUBSTR (TO_CHAR(columnname), 1, LENGTH (columnname) - 3),
                                '_',
                                ''
                               )
                    || '_'
                    || REPLACE (tablename, '_', ''),
                    1,
                    30
                   )
         || ' FOREIGN KEY ('
         || columnname
         || ') REFERENCES '
         || table_ref
         || ');'||CHR(10) cmd  /* for oracle */
    -- || ' DEFERRABLE INITIALLY DEFERRED;'||chr(10) cmd  /* for postgresql */
FROM     (
-- Table Direct or Search Table Direct
          SELECT t.tablename, c.columnname, r.NAME, c.ad_reference_id,
                 c.ad_reference_value_id,
                 CAST (SUBSTR (columnname, 1, LENGTH (columnname) - 3) AS VARCHAR2(40)) table_ref
            FROM AD_TABLE t, AD_COLUMN c, AD_REFERENCE r
           WHERE t.ad_table_id = c.ad_table_id
--           AND t.tablename LIKE 'ASP\_%' ESCAPE '\'
             AND t.isactive='Y'
             AND c.isactive='Y'
             AND c.columnsql IS NULL
             AND c.ad_reference_id = r.ad_reference_id
             AND (   c.ad_reference_id IN (19 /*Table Direct*/)
                  OR (    c.ad_reference_id IN (30 /*Search*/)
                      AND c.ad_reference_value_id IS NULL
                     )
                 )
          UNION
-- Table or Search
          SELECT t.tablename, c.columnname, r.NAME, c.ad_reference_id,
                 c.ad_reference_value_id, tr.tablename
            FROM AD_TABLE t,
                 AD_COLUMN c,
                 AD_REFERENCE r,
                 AD_REF_TABLE rt,
                 AD_TABLE tr
           WHERE t.ad_table_id = c.ad_table_id
--           AND t.tablename LIKE 'ASP\_%' ESCAPE '\'
             AND t.isactive='Y'
             AND c.isactive='Y'
             AND c.columnsql IS NULL
             AND c.ad_reference_id = r.ad_reference_id
             AND (   c.ad_reference_id IN (18 /*Table*/)
                  OR (    c.ad_reference_id IN (30 /*Search*/)
                      AND c.ad_reference_value_id IS NOT NULL
                     )
                 )
             AND c.ad_reference_value_id = rt.ad_reference_id
             AND rt.ad_table_id = tr.ad_table_id) v
   WHERE v.columnname NOT IN
                      ('AD_Client_ID', 'AD_Org_ID', 'CreatedBy', 'UpdatedBy')
     AND v.tablename NOT LIKE 'T\_%' ESCAPE '\'
     AND v.tablename NOT IN ('Test')
     -- exclude views
     AND NOT EXISTS (
               SELECT 1
                 FROM user_objects
                WHERE object_name = UPPER (v.tablename)
                  AND object_type = 'VIEW')
     -- exclude already existing foreign keys
     AND NOT EXISTS (
            SELECT 1
              FROM user_constraints c,
                   user_cons_columns cc,
                   user_constraints ck
             WHERE c.table_name = UPPER (v.tablename)
               AND cc.column_name = UPPER (v.columnname)
               AND c.constraint_name = cc.constraint_name
               AND c.r_constraint_name = ck.constraint_name
               AND ck.constraint_type = 'P'
               AND c.constraint_type = 'R'
               AND ck.table_name = UPPER (v.table_ref))
ORDER BY v.tablename, v.table_ref, v.columnname
