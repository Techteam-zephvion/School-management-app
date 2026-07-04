-- Class teachers get the same per-student editing an admin has, scoped to
-- students in a section they class-teach (blood group, address, name, dob,
-- gender...). Additive UPDATE policy; delete + admission-number changes stay
-- admin-only via the existing students_write policy.
create policy students_update_class_teacher on public.students
for update using (id in (select private.my_class_student_ids()))
with check (id in (select private.my_class_student_ids()));
