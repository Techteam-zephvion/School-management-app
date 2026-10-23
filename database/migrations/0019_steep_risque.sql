CREATE TABLE "staff_leave_substitutions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"staff_leave_id" uuid NOT NULL,
	"timetable_entry_id" uuid NOT NULL,
	"substitute_staff_id" uuid NOT NULL,
	"assigned_by_user_id" uuid,
	"notified_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "staff_leave_substitutions_staff_leave_id_timetable_entry_id_unique" UNIQUE("staff_leave_id","timetable_entry_id")
);
--> statement-breakpoint
ALTER TABLE "staff_leave_substitutions" ADD CONSTRAINT "staff_leave_substitutions_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_leave_substitutions" ADD CONSTRAINT "staff_leave_substitutions_staff_leave_id_staff_leaves_id_fk" FOREIGN KEY ("staff_leave_id") REFERENCES "public"."staff_leaves"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_leave_substitutions" ADD CONSTRAINT "staff_leave_substitutions_timetable_entry_id_timetable_entries_id_fk" FOREIGN KEY ("timetable_entry_id") REFERENCES "public"."timetable_entries"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_leave_substitutions" ADD CONSTRAINT "staff_leave_substitutions_substitute_staff_id_staff_id_fk" FOREIGN KEY ("substitute_staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_leave_substitutions" ADD CONSTRAINT "staff_leave_substitutions_assigned_by_user_id_app_users_id_fk" FOREIGN KEY ("assigned_by_user_id") REFERENCES "public"."app_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "staff_leave_substitute_idx" ON "staff_leave_substitutions" USING btree ("school_id","substitute_staff_id");