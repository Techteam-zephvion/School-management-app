CREATE TYPE "public"."assessment_component_type" AS ENUM('periodic_test', 'multiple_assessment', 'portfolio', 'subject_enrichment', 'term_exam', 'internal_assessment', 'board_exam', 'formative_assessment', 'summative_assessment', 'practical');--> statement-breakpoint
CREATE TYPE "public"."grading_board" AS ENUM('cbse', 'icse', 'state_board', 'cambridge', 'custom');--> statement-breakpoint
CREATE TYPE "public"."grading_term" AS ENUM('term_1', 'term_2', 'annual', 'all_terms');--> statement-breakpoint
CREATE TYPE "public"."offline_sync_status" AS ENUM('success', 'partial_conflict', 'failed');--> statement-breakpoint
CREATE TYPE "public"."report_card_result_status" AS ENUM('passed', 'promoted', 'compartment', 'failed', 'under_review');--> statement-breakpoint
CREATE TABLE "evaluation_components" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"scheme_id" uuid NOT NULL,
	"name" text NOT NULL,
	"component_type" "assessment_component_type" NOT NULL,
	"term" "grading_term" DEFAULT 'annual' NOT NULL,
	"weightage_percentage" integer NOT NULL,
	"max_marks" integer NOT NULL,
	"order_index" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "grading_scales" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"scheme_id" uuid NOT NULL,
	"grade" text NOT NULL,
	"min_score" integer NOT NULL,
	"max_score" integer NOT NULL,
	"grade_point" text NOT NULL,
	"remarks" text,
	"order_index" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "grading_schemes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"academic_year_id" uuid,
	"name" text NOT NULL,
	"board" "grading_board" DEFAULT 'cbse' NOT NULL,
	"description" text,
	"is_default" boolean DEFAULT false NOT NULL,
	"passing_percentage" integer DEFAULT 33 NOT NULL,
	"config" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "offline_attendance_sync_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"staff_id" uuid NOT NULL,
	"client_sync_batch_id" text NOT NULL,
	"payload_records_count" integer NOT NULL,
	"synced_count" integer NOT NULL,
	"conflict_count" integer DEFAULT 0 NOT NULL,
	"status" "offline_sync_status" DEFAULT 'success' NOT NULL,
	"details" text,
	"synced_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "student_report_cards" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"academic_year_id" uuid NOT NULL,
	"class_id" uuid NOT NULL,
	"section_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"scheme_id" uuid NOT NULL,
	"term" "grading_term" DEFAULT 'annual' NOT NULL,
	"total_max_marks" integer NOT NULL,
	"total_obtained_marks" integer NOT NULL,
	"overall_percentage" text NOT NULL,
	"overall_grade" text NOT NULL,
	"overall_grade_point" text,
	"attendance_percentage" text,
	"scholastic_data" text NOT NULL,
	"co_scholastic_data" text,
	"teacher_remarks" text,
	"principal_remarks" text,
	"result_status" "report_card_result_status" DEFAULT 'promoted' NOT NULL,
	"is_published" boolean DEFAULT false NOT NULL,
	"published_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "student_report_cards_school_id_academic_year_id_student_id_term_unique" UNIQUE("school_id","academic_year_id","student_id","term")
);
--> statement-breakpoint
ALTER TABLE "evaluation_components" ADD CONSTRAINT "evaluation_components_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "evaluation_components" ADD CONSTRAINT "evaluation_components_scheme_id_grading_schemes_id_fk" FOREIGN KEY ("scheme_id") REFERENCES "public"."grading_schemes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "grading_scales" ADD CONSTRAINT "grading_scales_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "grading_scales" ADD CONSTRAINT "grading_scales_scheme_id_grading_schemes_id_fk" FOREIGN KEY ("scheme_id") REFERENCES "public"."grading_schemes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "grading_schemes" ADD CONSTRAINT "grading_schemes_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "grading_schemes" ADD CONSTRAINT "grading_schemes_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "offline_attendance_sync_logs" ADD CONSTRAINT "offline_attendance_sync_logs_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "offline_attendance_sync_logs" ADD CONSTRAINT "offline_attendance_sync_logs_staff_id_staff_id_fk" FOREIGN KEY ("staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_report_cards" ADD CONSTRAINT "student_report_cards_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_report_cards" ADD CONSTRAINT "student_report_cards_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_report_cards" ADD CONSTRAINT "student_report_cards_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_report_cards" ADD CONSTRAINT "student_report_cards_section_id_sections_id_fk" FOREIGN KEY ("section_id") REFERENCES "public"."sections"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_report_cards" ADD CONSTRAINT "student_report_cards_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_report_cards" ADD CONSTRAINT "student_report_cards_scheme_id_grading_schemes_id_fk" FOREIGN KEY ("scheme_id") REFERENCES "public"."grading_schemes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "eval_components_scheme_idx" ON "evaluation_components" USING btree ("school_id","scheme_id","term");--> statement-breakpoint
CREATE INDEX "grading_scales_scheme_idx" ON "grading_scales" USING btree ("school_id","scheme_id","order_index");--> statement-breakpoint
CREATE INDEX "grading_schemes_school_idx" ON "grading_schemes" USING btree ("school_id","academic_year_id");--> statement-breakpoint
CREATE INDEX "offline_sync_school_staff_idx" ON "offline_attendance_sync_logs" USING btree ("school_id","staff_id","synced_at");--> statement-breakpoint
CREATE INDEX "offline_sync_batch_idx" ON "offline_attendance_sync_logs" USING btree ("school_id","client_sync_batch_id");--> statement-breakpoint
CREATE INDEX "report_cards_section_idx" ON "student_report_cards" USING btree ("school_id","section_id","term");--> statement-breakpoint
CREATE INDEX "report_cards_student_idx" ON "student_report_cards" USING btree ("school_id","student_id");