CREATE TYPE "public"."admission_status" AS ENUM('inquiry', 'applied', 'under_review', 'approved', 'enrolled', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."document_status" AS ENUM('pending', 'submitted', 'verified', 'rejected');--> statement-breakpoint
CREATE TABLE "admission_applications" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"academic_year_id" uuid NOT NULL,
	"applying_for_class_id" uuid NOT NULL,
	"application_number" text NOT NULL,
	"applicant_name" text NOT NULL,
	"date_of_birth" date,
	"gender" text,
	"parent_name" text NOT NULL,
	"parent_email" text,
	"parent_phone" text NOT NULL,
	"address" text,
	"previous_school" text,
	"status" "admission_status" DEFAULT 'applied' NOT NULL,
	"application_date" date NOT NULL,
	"decision_date" date,
	"enrolled_student_id" uuid,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "admission_applications_school_id_application_number_unique" UNIQUE("school_id","application_number")
);
--> statement-breakpoint
CREATE TABLE "admission_documents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"application_id" uuid NOT NULL,
	"title" text NOT NULL,
	"status" "document_status" DEFAULT 'pending' NOT NULL,
	"document_number" text,
	"verified_by_staff_id" uuid,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "admission_applications" ADD CONSTRAINT "admission_applications_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "admission_applications" ADD CONSTRAINT "admission_applications_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "admission_applications" ADD CONSTRAINT "admission_applications_applying_for_class_id_classes_id_fk" FOREIGN KEY ("applying_for_class_id") REFERENCES "public"."classes"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "admission_applications" ADD CONSTRAINT "admission_applications_enrolled_student_id_students_id_fk" FOREIGN KEY ("enrolled_student_id") REFERENCES "public"."students"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "admission_documents" ADD CONSTRAINT "admission_documents_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "admission_documents" ADD CONSTRAINT "admission_documents_application_id_admission_applications_id_fk" FOREIGN KEY ("application_id") REFERENCES "public"."admission_applications"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "admission_documents" ADD CONSTRAINT "admission_documents_verified_by_staff_id_staff_id_fk" FOREIGN KEY ("verified_by_staff_id") REFERENCES "public"."staff"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "admission_app_status_idx" ON "admission_applications" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "admission_app_year_class_idx" ON "admission_applications" USING btree ("school_id","academic_year_id","applying_for_class_id");--> statement-breakpoint
CREATE INDEX "admission_docs_app_idx" ON "admission_documents" USING btree ("school_id","application_id");