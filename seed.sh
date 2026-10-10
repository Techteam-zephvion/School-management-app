#!/bin/bash
USER_RES=$(curl -sS -X POST http://localhost:8787/api/v1/admin/users -H "x-dev-neon-user-id: dev-admin" -H "x-dev-email: admin@schoolic.local" -H "Content-Type: application/json" -d '{"neonUserId":"dev-teacher","email":"teacher@schoolic.local","displayName":"Dev Teacher","roles":["teacher"]}')
USER_ID=$(echo $USER_RES | jq -r .id)
echo "User ID: $USER_ID"

STAFF_RES=$(curl -sS -X POST http://localhost:8787/api/v1/admin/staff -H "x-dev-neon-user-id: dev-admin" -H "x-dev-email: admin@schoolic.local" -H "Content-Type: application/json" -d "{\"staffCode\":\"TCH-01\",\"fullName\":\"Dev Teacher\",\"email\":\"teacher@schoolic.local\",\"isTeacher\":true,\"userId\":\"$USER_ID\"}")
STAFF_ID=$(echo $STAFF_RES | jq -r .id)
echo "Staff ID: $STAFF_ID"

curl -sS -X POST http://localhost:8787/api/v1/admin/students -H "x-dev-neon-user-id: dev-admin" -H "x-dev-email: admin@schoolic.local" -H "Content-Type: application/json" -d '{"admissionNumber":"STU-001","fullName":"Alice Student","academicYearId":"a0a605e3-a98b-471c-8b62-88990706dd9d","classId":"20b6250b-bca3-440d-bdde-d31e35988ad8","sectionId":"484fcd24-b4c1-4054-8add-a69d27fed160","rollNumber":"1"}'
echo ""

curl -sS -X POST http://localhost:8787/api/v1/admin/students -H "x-dev-neon-user-id: dev-admin" -H "x-dev-email: admin@schoolic.local" -H "Content-Type: application/json" -d '{"admissionNumber":"STU-002","fullName":"Bob Student","academicYearId":"a0a605e3-a98b-471c-8b62-88990706dd9d","classId":"20b6250b-bca3-440d-bdde-d31e35988ad8","sectionId":"484fcd24-b4c1-4054-8add-a69d27fed160","rollNumber":"2"}'
echo ""

curl -sS -X POST http://localhost:8787/api/v1/admin/teacher-assignments -H "x-dev-neon-user-id: dev-admin" -H "x-dev-email: admin@schoolic.local" -H "Content-Type: application/json" -d "{\"staffId\":\"$STAFF_ID\",\"academicYearId\":\"a0a605e3-a98b-471c-8b62-88990706dd9d\",\"classId\":\"20b6250b-bca3-440d-bdde-d31e35988ad8\",\"sectionId\":\"484fcd24-b4c1-4054-8add-a69d27fed160\",\"subjectId\":\"f50e6cc7-e6ab-46ae-b24a-7cdbf666b58f\",\"canTakeDailyAttendance\":true}"
echo ""
