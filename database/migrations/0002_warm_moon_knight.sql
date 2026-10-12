CREATE TYPE "public"."teaching_material_type" AS ENUM('lesson_plan', 'worksheet', 'quiz');--> statement-breakpoint
CREATE TABLE "teacher_materials" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"owner_staff_id" uuid NOT NULL,
	"academic_year_id" uuid,
	"class_id" uuid,
	"section_id" uuid,
	"subject_id" uuid,
	"type" "teaching_material_type" NOT NULL,
	"title" text NOT NULL,
	"topic" text NOT NULL,
	"difficulty" text NOT NULL,
	"language" text DEFAULT 'English' NOT NULL,
	"duration_minutes" integer,
	"question_count" integer,
	"content" jsonb NOT NULL,
	"metadata" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "teacher_materials" ADD CONSTRAINT "teacher_materials_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "teacher_materials" ADD CONSTRAINT "teacher_materials_owner_staff_id_staff_id_fk" FOREIGN KEY ("owner_staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "teacher_materials" ADD CONSTRAINT "teacher_materials_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "teacher_materials" ADD CONSTRAINT "teacher_materials_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "teacher_materials" ADD CONSTRAINT "teacher_materials_section_id_sections_id_fk" FOREIGN KEY ("section_id") REFERENCES "public"."sections"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "teacher_materials" ADD CONSTRAINT "teacher_materials_subject_id_subjects_id_fk" FOREIGN KEY ("subject_id") REFERENCES "public"."subjects"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "teacher_materials_owner_idx" ON "teacher_materials" USING btree ("school_id","owner_staff_id","updated_at");--> statement-breakpoint
CREATE INDEX "teacher_materials_context_idx" ON "teacher_materials" USING btree ("school_id","class_id","section_id","subject_id");