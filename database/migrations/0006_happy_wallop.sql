CREATE TYPE "public"."homework_status" AS ENUM('draft', 'published', 'archived');--> statement-breakpoint
CREATE TABLE "homework_assignments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"owner_staff_id" uuid NOT NULL,
	"academic_year_id" uuid NOT NULL,
	"class_id" uuid NOT NULL,
	"section_id" uuid NOT NULL,
	"subject_id" uuid,
	"title" text NOT NULL,
	"instructions" text NOT NULL,
	"due_date" date NOT NULL,
	"estimated_minutes" integer,
	"status" "homework_status" DEFAULT 'published' NOT NULL,
	"source_material_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "homework_assignments" ADD CONSTRAINT "homework_assignments_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "homework_assignments" ADD CONSTRAINT "homework_assignments_owner_staff_id_staff_id_fk" FOREIGN KEY ("owner_staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "homework_assignments" ADD CONSTRAINT "homework_assignments_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "homework_assignments" ADD CONSTRAINT "homework_assignments_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "homework_assignments" ADD CONSTRAINT "homework_assignments_section_id_sections_id_fk" FOREIGN KEY ("section_id") REFERENCES "public"."sections"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "homework_assignments" ADD CONSTRAINT "homework_assignments_subject_id_subjects_id_fk" FOREIGN KEY ("subject_id") REFERENCES "public"."subjects"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "homework_assignments" ADD CONSTRAINT "homework_assignments_source_material_id_teacher_materials_id_fk" FOREIGN KEY ("source_material_id") REFERENCES "public"."teacher_materials"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "homework_assignments_teacher_idx" ON "homework_assignments" USING btree ("school_id","owner_staff_id","due_date");--> statement-breakpoint
CREATE INDEX "homework_assignments_section_idx" ON "homework_assignments" USING btree ("school_id","academic_year_id","section_id","due_date");