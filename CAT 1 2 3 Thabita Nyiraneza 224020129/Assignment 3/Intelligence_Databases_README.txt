Intelligence Databases – README file


This project contains five exercises showing how to use database intelligence features such as declarative rules, triggers, recursion, ontology reasoning, and spatial queries.  
For each task, fix the buggy starter code, run your corrected SQL, and show both failing and passing test results.


1. Rules (Declarative Constraints): Safe Prescriptions

Create a reliable table PATIENT_MED under HEALTHNET that automatically rejects invalid prescription data.

Tasks:
- Fix the buggy CREATE TABLE PATIENT_MED code by:
  • Adding missing commas and NOT NULL keywords.
  • Correcting the CHECK clause syntax.
  • Ensuring the date rule uses valid SQL logic (START_DT <= END_DT).
- Enforce:
  • Non-negative doses.
  • Mandatory PATIENT_ID and MED_NAME.
  • Referential integrity to PATIENT.
- Test:
  • 2 failing INSERTs (negative dose, missing patient, bad date order).
  • 2 passing INSERTs (valid prescriptions).


2. Active Databases (E–C–A Trigger): Bill Totals That Stay Correct

Maintain accurate bill totals automatically when bill items change.

Task:
- Replace the buggy TRG_BILL_TOTAL (row-level) with a statement-level or compound trigger (TRG_BILL_TOTAL_STMT or TRG_BILL_TOTAL_CMP).
- The trigger should:
  1. Collect all affected BILL_IDs.
  2. Recalculate totals once per bill after all DML.
  3. Insert an audit row into BILL_AUDIT.
- Run a small script mixing INSERT, UPDATE, and DELETE on BILL_ITEM.




3. Deductive Databases (Recursive WITH): Referral / Supervision Chain

Use recursion to find each employee’s top supervisor and number of hops.

Task:
- Correct the recursive WITH query:
  • Fix anchor hop count (start from 1).
  • Reverse the join direction so recursion climbs the supervision chain correctly.
  • Add a simple cycle guard using a path check.
- Run it on a demo STAFF_SUPERVISOR table with 5–6 rows.


4. Knowledge Bases (Triples & Ontology): Infectious-Disease Roll-Up

Identify patients diagnosed with diseases that are subclasses of “InfectiousDisease”.

We are going to:
- Fix direction errors in the recursive isA query:
  • Ensure recursion moves from child → ancestor.
  • Compare ISA.ANCESTOR (not CHILD) to 'InfectiousDisease'.
- Build about 8 sample triples (including some with isA and hasDiagnosis).
- Query patients whose diagnosis isA* InfectiousDisease.


5. Spatial Databases (Geography & Distance): Radius & Nearest-3


We are going to Use spatial SQL to find clinics near an ambulance location.

What I have to do:
- Fix SRID to 4326 (WGS84) and correct point order (lon, lat).
- Build the ambulance point using:
  SDO_GEOMETRY(2001, 4326, SDO_POINT_TYPE(30.0600, -1.9570, NULL), NULL, NULL)
- Query 1: Clinics within 1 km using SDO_WITHIN_DISTANCE with 'distance=1 unit=KM'.
- Query 2: The nearest 3 clinics, computing distance with SDO_GEOM.SDO_DISTANCE(..., 'unit=KM').





