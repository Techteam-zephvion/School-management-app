CREATE TYPE "public"."alumni_verification_status" AS ENUM('pending', 'verified', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."biometric_device_status" AS ENUM('online', 'offline', 'maintenance');--> statement-breakpoint
CREATE TYPE "public"."biometric_device_type" AS ENUM('fingerprint', 'facial_recognition', 'rfid_card', 'turnstile');--> statement-breakpoint
CREATE TYPE "public"."biometric_punch_status" AS ENUM('pending', 'reconciled', 'ignored', 'error');--> statement-breakpoint
CREATE TYPE "public"."biometric_punch_type" AS ENUM('in', 'out', 'auto');--> statement-breakpoint
CREATE TYPE "public"."bloom_level" AS ENUM('remember', 'understand', 'apply', 'analyze', 'evaluate', 'create');--> statement-breakpoint
CREATE TYPE "public"."campus_transfer_status" AS ENUM('pending', 'approved', 'rejected', 'completed');--> statement-breakpoint
CREATE TYPE "public"."question_type" AS ENUM('mcq', 'short_answer', 'long_answer', 'numerical');--> statement-breakpoint
CREATE TYPE "public"."transcript_request_status" AS ENUM('submitted', 'processing', 'ready', 'dispatched', 'rejected');--> statement-breakpoint
CREATE TABLE "alumni_profiles" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid,
	"full_name" text NOT NULL,
	"email" text NOT NULL,
	"phone" text,
	"graduation_year" integer NOT NULL,
	"higher_education" text,
	"current_organization" text,
	"designation" text,
	"industry" text,
	"linkedin_url" text,
	"mentorship_available" boolean DEFAULT false NOT NULL,
	"verification_status" "alumni_verification_status" DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "biometric_devices" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"name" text NOT NULL,
	"device_code" text NOT NULL,
	"device_type" "biometric_device_type" DEFAULT 'facial_recognition' NOT NULL,
	"ip_address" text,
	"mac_address" text,
	"serial_number" text,
	"location" text NOT NULL,
	"status" "biometric_device_status" DEFAULT 'offline' NOT NULL,
	"last_heartbeat_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "biometric_devices_school_id_device_code_unique" UNIQUE("school_id","device_code")
);
--> statement-breakpoint
CREATE TABLE "biometric_punch_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"device_id" uuid NOT NULL,
	"user_type" text DEFAULT 'student' NOT NULL,
	"student_id" uuid,
	"staff_id" uuid,
	"card_or_token_number" text NOT NULL,
	"punch_timestamp" timestamp with time zone NOT NULL,
	"punch_type" "biometric_punch_type" DEFAULT 'auto' NOT NULL,
	"status" "biometric_punch_status" DEFAULT 'pending' NOT NULL,
	"raw_payload" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "campus_transfers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"trust_id" uuid NOT NULL,
	"source_school_id" uuid NOT NULL,
	"target_school_id" uuid NOT NULL,
	"entity_type" text DEFAULT 'student' NOT NULL,
	"student_id" uuid,
	"staff_id" uuid,
	"target_class_id" uuid,
	"reason" text NOT NULL,
	"status" "campus_transfer_status" DEFAULT 'pending' NOT NULL,
	"transfer_date" date,
	"remarks" text,
	"approved_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "course_outcomes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"class_id" uuid NOT NULL,
	"subject_id" uuid NOT NULL,
	"code" text NOT NULL,
	"description" text NOT NULL,
	"target_attainment_percent" integer DEFAULT 70 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "course_outcomes_school_id_class_id_subject_id_code_unique" UNIQUE("school_id","class_id","subject_id","code")
);
--> statement-breakpoint
CREATE TABLE "educational_trusts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"name" text NOT NULL,
	"code" text NOT NULL,
	"registration_number" text,
	"address" text,
	"contact_email" text,
	"contact_phone" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "educational_trusts_code_unique" UNIQUE("code")
);
--> statement-breakpoint
CREATE TABLE "exam_questions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"class_id" uuid NOT NULL,
	"subject_id" uuid NOT NULL,
	"course_outcome_id" uuid,
	"question_text" text NOT NULL,
	"question_type" "question_type" DEFAULT 'short_answer' NOT NULL,
	"bloom_level" "bloom_level" DEFAULT 'understand' NOT NULL,
	"marks" integer DEFAULT 2 NOT NULL,
	"options" text,
	"answer_key" text,
	"rubrics" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transcript_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"alumni_id" uuid NOT NULL,
	"request_number" text NOT NULL,
	"document_type" text NOT NULL,
	"copies" integer DEFAULT 1 NOT NULL,
	"delivery_mode" text DEFAULT 'digital' NOT NULL,
	"shipping_address" text,
	"status" "transcript_request_status" DEFAULT 'submitted' NOT NULL,
	"fee_paid" boolean DEFAULT false NOT NULL,
	"issued_document_key" text,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "schools" ADD COLUMN "trust_id" uuid;--> statement-breakpoint
ALTER TABLE "alumni_profiles" ADD CONSTRAINT "alumni_profiles_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "alumni_profiles" ADD CONSTRAINT "alumni_profiles_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "biometric_devices" ADD CONSTRAINT "biometric_devices_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "biometric_punch_logs" ADD CONSTRAINT "biometric_punch_logs_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "biometric_punch_logs" ADD CONSTRAINT "biometric_punch_logs_device_id_biometric_devices_id_fk" FOREIGN KEY ("device_id") REFERENCES "public"."biometric_devices"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "biometric_punch_logs" ADD CONSTRAINT "biometric_punch_logs_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "biometric_punch_logs" ADD CONSTRAINT "biometric_punch_logs_staff_id_staff_id_fk" FOREIGN KEY ("staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "campus_transfers" ADD CONSTRAINT "campus_transfers_trust_id_educational_trusts_id_fk" FOREIGN KEY ("trust_id") REFERENCES "public"."educational_trusts"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "campus_transfers" ADD CONSTRAINT "campus_transfers_source_school_id_schools_id_fk" FOREIGN KEY ("source_school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "campus_transfers" ADD CONSTRAINT "campus_transfers_target_school_id_schools_id_fk" FOREIGN KEY ("target_school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "campus_transfers" ADD CONSTRAINT "campus_transfers_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "campus_transfers" ADD CONSTRAINT "campus_transfers_staff_id_staff_id_fk" FOREIGN KEY ("staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "campus_transfers" ADD CONSTRAINT "campus_transfers_target_class_id_classes_id_fk" FOREIGN KEY ("target_class_id") REFERENCES "public"."classes"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "campus_transfers" ADD CONSTRAINT "campus_transfers_approved_by_user_id_app_users_id_fk" FOREIGN KEY ("approved_by_user_id") REFERENCES "public"."app_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_outcomes" ADD CONSTRAINT "course_outcomes_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_outcomes" ADD CONSTRAINT "course_outcomes_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "course_outcomes" ADD CONSTRAINT "course_outcomes_subject_id_subjects_id_fk" FOREIGN KEY ("subject_id") REFERENCES "public"."subjects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_questions" ADD CONSTRAINT "exam_questions_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_questions" ADD CONSTRAINT "exam_questions_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_questions" ADD CONSTRAINT "exam_questions_subject_id_subjects_id_fk" FOREIGN KEY ("subject_id") REFERENCES "public"."subjects"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "exam_questions" ADD CONSTRAINT "exam_questions_course_outcome_id_course_outcomes_id_fk" FOREIGN KEY ("course_outcome_id") REFERENCES "public"."course_outcomes"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transcript_requests" ADD CONSTRAINT "transcript_requests_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transcript_requests" ADD CONSTRAINT "transcript_requests_alumni_id_alumni_profiles_id_fk" FOREIGN KEY ("alumni_id") REFERENCES "public"."alumni_profiles"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "alumni_school_year_idx" ON "alumni_profiles" USING btree ("school_id","graduation_year","verification_status");--> statement-breakpoint
CREATE INDEX "biometric_devices_school_status_idx" ON "biometric_devices" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "punch_logs_school_time_idx" ON "biometric_punch_logs" USING btree ("school_id","punch_timestamp","status");--> statement-breakpoint
CREATE INDEX "transfers_trust_status_idx" ON "campus_transfers" USING btree ("trust_id","status");--> statement-breakpoint
CREATE INDEX "transfers_source_target_idx" ON "campus_transfers" USING btree ("source_school_id","target_school_id");--> statement-breakpoint
CREATE INDEX "course_outcomes_school_idx" ON "course_outcomes" USING btree ("school_id","class_id","subject_id");--> statement-breakpoint
CREATE INDEX "exam_questions_school_subject_idx" ON "exam_questions" USING btree ("school_id","class_id","subject_id","bloom_level");--> statement-breakpoint
CREATE INDEX "transcripts_school_status_idx" ON "transcript_requests" USING btree ("school_id","status","request_number");--> statement-breakpoint
ALTER TABLE "schools" ADD CONSTRAINT "schools_trust_id_educational_trusts_id_fk" FOREIGN KEY ("trust_id") REFERENCES "public"."educational_trusts"("id") ON DELETE set null ON UPDATE no action;