CREATE TYPE "public"."concession_type" AS ENUM('percentage', 'flat');--> statement-breakpoint
CREATE TYPE "public"."consent_status" AS ENUM('granted', 'revoked', 'expired');--> statement-breakpoint
CREATE TYPE "public"."dsr_status" AS ENUM('pending', 'in_review', 'fulfilled', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."fee_refund_status" AS ENUM('pending', 'approved', 'processed', 'rejected');--> statement-breakpoint
ALTER TYPE "public"."role" ADD VALUE 'accountant';--> statement-breakpoint
ALTER TYPE "public"."role" ADD VALUE 'admissions_officer';--> statement-breakpoint
ALTER TYPE "public"."role" ADD VALUE 'principal';--> statement-breakpoint
CREATE TABLE "audit_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"user_id" uuid,
	"user_email" text NOT NULL,
	"user_role" text NOT NULL,
	"action" text NOT NULL,
	"resource_type" text NOT NULL,
	"resource_id" text,
	"ip_address" text,
	"details" jsonb,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "data_subject_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"requester_user_id" uuid,
	"requester_role" text NOT NULL,
	"student_id" uuid,
	"request_type" text NOT NULL,
	"status" "dsr_status" DEFAULT 'pending' NOT NULL,
	"reason" text NOT NULL,
	"resolution_notes" text,
	"resolved_at" timestamp with time zone,
	"resolved_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "dpdp_consents" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"parent_guardian_name" text NOT NULL,
	"parent_guardian_phone" text NOT NULL,
	"consent_type" text NOT NULL,
	"status" "consent_status" DEFAULT 'granted' NOT NULL,
	"verified_via" text DEFAULT 'portal_submission' NOT NULL,
	"ip_address" text,
	"valid_until" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "fee_concessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"name" text NOT NULL,
	"code" text NOT NULL,
	"type" "concession_type" DEFAULT 'flat' NOT NULL,
	"value" integer NOT NULL,
	"category" text DEFAULT 'merit' NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "fee_concessions_school_id_code_unique" UNIQUE("school_id","code")
);
--> statement-breakpoint
CREATE TABLE "fee_refunds" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"allocation_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"payment_id" uuid,
	"refund_number" text NOT NULL,
	"amount" integer NOT NULL,
	"reason" text NOT NULL,
	"mode" text DEFAULT 'bank_transfer' NOT NULL,
	"reference_number" text,
	"status" "fee_refund_status" DEFAULT 'pending' NOT NULL,
	"approved_by_user_id" uuid,
	"processed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "fee_refunds_school_id_refund_number_unique" UNIQUE("school_id","refund_number")
);
--> statement-breakpoint
CREATE TABLE "fee_structure_heads" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"fee_structure_id" uuid NOT NULL,
	"head_name" text NOT NULL,
	"amount" integer NOT NULL,
	"is_optional" boolean DEFAULT false NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "student_fee_concessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"allocation_id" uuid NOT NULL,
	"concession_id" uuid NOT NULL,
	"applied_amount" integer NOT NULL,
	"reason" text,
	"approved_by_user_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "fee_structures" ADD COLUMN "late_fee_grace_period_days" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "fee_structures" ADD COLUMN "late_fee_type" text DEFAULT 'none' NOT NULL;--> statement-breakpoint
ALTER TABLE "fee_structures" ADD COLUMN "late_fee_amount" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "sections" ADD COLUMN "class_teacher_staff_id" uuid;--> statement-breakpoint
ALTER TABLE "audit_logs" ADD CONSTRAINT "audit_logs_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_subject_requests" ADD CONSTRAINT "data_subject_requests_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_subject_requests" ADD CONSTRAINT "data_subject_requests_requester_user_id_app_users_id_fk" FOREIGN KEY ("requester_user_id") REFERENCES "public"."app_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_subject_requests" ADD CONSTRAINT "data_subject_requests_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "data_subject_requests" ADD CONSTRAINT "data_subject_requests_resolved_by_user_id_app_users_id_fk" FOREIGN KEY ("resolved_by_user_id") REFERENCES "public"."app_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "dpdp_consents" ADD CONSTRAINT "dpdp_consents_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "dpdp_consents" ADD CONSTRAINT "dpdp_consents_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_concessions" ADD CONSTRAINT "fee_concessions_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_refunds" ADD CONSTRAINT "fee_refunds_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_refunds" ADD CONSTRAINT "fee_refunds_allocation_id_student_fee_allocations_id_fk" FOREIGN KEY ("allocation_id") REFERENCES "public"."student_fee_allocations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_refunds" ADD CONSTRAINT "fee_refunds_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_refunds" ADD CONSTRAINT "fee_refunds_payment_id_fee_payments_id_fk" FOREIGN KEY ("payment_id") REFERENCES "public"."fee_payments"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_refunds" ADD CONSTRAINT "fee_refunds_approved_by_user_id_app_users_id_fk" FOREIGN KEY ("approved_by_user_id") REFERENCES "public"."app_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_structure_heads" ADD CONSTRAINT "fee_structure_heads_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_structure_heads" ADD CONSTRAINT "fee_structure_heads_fee_structure_id_fee_structures_id_fk" FOREIGN KEY ("fee_structure_id") REFERENCES "public"."fee_structures"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_fee_concessions" ADD CONSTRAINT "student_fee_concessions_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_fee_concessions" ADD CONSTRAINT "student_fee_concessions_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_fee_concessions" ADD CONSTRAINT "student_fee_concessions_allocation_id_student_fee_allocations_id_fk" FOREIGN KEY ("allocation_id") REFERENCES "public"."student_fee_allocations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_fee_concessions" ADD CONSTRAINT "student_fee_concessions_concession_id_fee_concessions_id_fk" FOREIGN KEY ("concession_id") REFERENCES "public"."fee_concessions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_fee_concessions" ADD CONSTRAINT "student_fee_concessions_approved_by_user_id_app_users_id_fk" FOREIGN KEY ("approved_by_user_id") REFERENCES "public"."app_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "audit_logs_school_created_idx" ON "audit_logs" USING btree ("school_id","created_at");--> statement-breakpoint
CREATE INDEX "audit_logs_school_resource_idx" ON "audit_logs" USING btree ("school_id","resource_type");--> statement-breakpoint
CREATE INDEX "audit_logs_user_idx" ON "audit_logs" USING btree ("school_id","user_id");--> statement-breakpoint
CREATE INDEX "dsr_school_status_idx" ON "data_subject_requests" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "dsr_requester_idx" ON "data_subject_requests" USING btree ("school_id","requester_user_id");--> statement-breakpoint
CREATE INDEX "dpdp_consent_student_idx" ON "dpdp_consents" USING btree ("school_id","student_id");--> statement-breakpoint
CREATE INDEX "dpdp_consent_status_idx" ON "dpdp_consents" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "fee_concessions_active_idx" ON "fee_concessions" USING btree ("school_id","is_active");--> statement-breakpoint
CREATE INDEX "fee_refunds_alloc_idx" ON "fee_refunds" USING btree ("school_id","allocation_id");--> statement-breakpoint
CREATE INDEX "fee_refunds_student_idx" ON "fee_refunds" USING btree ("school_id","student_id");--> statement-breakpoint
CREATE INDEX "fee_refunds_status_idx" ON "fee_refunds" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "fee_heads_structure_idx" ON "fee_structure_heads" USING btree ("school_id","fee_structure_id");--> statement-breakpoint
CREATE INDEX "student_concessions_student_idx" ON "student_fee_concessions" USING btree ("school_id","student_id");--> statement-breakpoint
CREATE INDEX "student_concessions_alloc_idx" ON "student_fee_concessions" USING btree ("school_id","allocation_id");--> statement-breakpoint
ALTER TABLE "sections" ADD CONSTRAINT "sections_class_teacher_staff_id_staff_id_fk" FOREIGN KEY ("class_teacher_staff_id") REFERENCES "public"."staff"("id") ON DELETE set null ON UPDATE no action;