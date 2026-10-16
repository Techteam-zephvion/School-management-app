CREATE TYPE "public"."calendar_event_type" AS ENUM('holiday', 'exam', 'sports', 'cultural', 'ptm', 'meeting', 'other');--> statement-breakpoint
CREATE TYPE "public"."certificate_status" AS ENUM('valid', 'revoked');--> statement-breakpoint
CREATE TYPE "public"."certificate_type" AS ENUM('transfer_certificate', 'bonafide', 'character_conduct');--> statement-breakpoint
CREATE TYPE "public"."leave_status" AS ENUM('pending', 'approved', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."leave_type" AS ENUM('casual', 'sick', 'earned', 'maternity_paternity', 'unpaid');--> statement-breakpoint
CREATE TYPE "public"."ptm_slot_status" AS ENUM('available', 'booked', 'completed', 'cancelled');--> statement-breakpoint
CREATE TYPE "public"."ptm_status" AS ENUM('scheduled', 'in_progress', 'completed', 'cancelled');--> statement-breakpoint
CREATE TABLE "calendar_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"academic_year_id" uuid,
	"title" text NOT NULL,
	"description" text,
	"event_type" "calendar_event_type" DEFAULT 'holiday' NOT NULL,
	"start_date" date NOT NULL,
	"end_date" date NOT NULL,
	"is_all_day" boolean DEFAULT true NOT NULL,
	"target_audience" text DEFAULT 'all' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "issued_certificates" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"certificate_type" "certificate_type" NOT NULL,
	"certificate_number" text NOT NULL,
	"academic_year_id" uuid,
	"issue_date" date NOT NULL,
	"verification_code" text NOT NULL,
	"metadata" jsonb,
	"issued_by_staff_id" uuid,
	"status" "certificate_status" DEFAULT 'valid' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "issued_certificates_school_id_certificate_number_unique" UNIQUE("school_id","certificate_number"),
	CONSTRAINT "issued_certificates_verification_code_unique" UNIQUE("verification_code")
);
--> statement-breakpoint
CREATE TABLE "ptm_schedules" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"academic_year_id" uuid,
	"title" text NOT NULL,
	"event_date" date NOT NULL,
	"start_time" text NOT NULL,
	"end_time" text NOT NULL,
	"slot_duration_minutes" integer DEFAULT 15 NOT NULL,
	"status" "ptm_status" DEFAULT 'scheduled' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "ptm_slots" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"schedule_id" uuid NOT NULL,
	"teacher_staff_id" uuid NOT NULL,
	"start_time" text NOT NULL,
	"end_time" text NOT NULL,
	"status" "ptm_slot_status" DEFAULT 'available' NOT NULL,
	"booked_by_student_id" uuid,
	"parent_notes" text,
	"teacher_notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "staff_leaves" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"staff_id" uuid NOT NULL,
	"leave_type" "leave_type" DEFAULT 'casual' NOT NULL,
	"start_date" date NOT NULL,
	"end_date" date NOT NULL,
	"reason" text NOT NULL,
	"status" "leave_status" DEFAULT 'pending' NOT NULL,
	"reviewed_by_user_id" uuid,
	"reviewer_notes" text,
	"reviewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "student_leaves" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"start_date" date NOT NULL,
	"end_date" date NOT NULL,
	"reason" text NOT NULL,
	"document_url" text,
	"status" "leave_status" DEFAULT 'pending' NOT NULL,
	"reviewed_by_staff_id" uuid,
	"reviewer_notes" text,
	"reviewed_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "student_transport_allocations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"route_id" uuid NOT NULL,
	"stop_id" uuid NOT NULL,
	"academic_year_id" uuid NOT NULL,
	"status" text DEFAULT 'active' NOT NULL,
	"start_date" date NOT NULL,
	"end_date" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transport_drivers" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"full_name" text NOT NULL,
	"phone" text NOT NULL,
	"license_number" text NOT NULL,
	"license_expiry" date,
	"status" text DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "transport_drivers_school_id_license_number_unique" UNIQUE("school_id","license_number")
);
--> statement-breakpoint
CREATE TABLE "transport_logs" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"route_id" uuid NOT NULL,
	"date" date NOT NULL,
	"trip_type" text NOT NULL,
	"status" text DEFAULT 'scheduled' NOT NULL,
	"current_stop_id" uuid,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transport_routes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"route_number" text NOT NULL,
	"route_name" text NOT NULL,
	"start_point" text NOT NULL,
	"end_point" text NOT NULL,
	"vehicle_id" uuid,
	"driver_id" uuid,
	"status" text DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "transport_routes_school_id_route_number_unique" UNIQUE("school_id","route_number")
);
--> statement-breakpoint
CREATE TABLE "transport_stops" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"route_id" uuid NOT NULL,
	"stop_name" text NOT NULL,
	"pickup_time" text NOT NULL,
	"drop_time" text NOT NULL,
	"stop_order" integer DEFAULT 1 NOT NULL,
	"monthly_fee_amount" integer DEFAULT 0 NOT NULL,
	"latitude" text,
	"longitude" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "transport_vehicles" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"vehicle_number" text NOT NULL,
	"model" text NOT NULL,
	"capacity" integer NOT NULL,
	"insurance_expiry" date,
	"pollution_expiry" date,
	"status" text DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "transport_vehicles_school_id_vehicle_number_unique" UNIQUE("school_id","vehicle_number")
);
--> statement-breakpoint
ALTER TABLE "admission_applications" ADD COLUMN "quota_category" text DEFAULT 'general' NOT NULL;--> statement-breakpoint
ALTER TABLE "admission_applications" ADD COLUMN "caste_category" text DEFAULT 'general' NOT NULL;--> statement-breakpoint
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "calendar_events" ADD CONSTRAINT "calendar_events_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "issued_certificates" ADD CONSTRAINT "issued_certificates_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "issued_certificates" ADD CONSTRAINT "issued_certificates_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "issued_certificates" ADD CONSTRAINT "issued_certificates_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "issued_certificates" ADD CONSTRAINT "issued_certificates_issued_by_staff_id_staff_id_fk" FOREIGN KEY ("issued_by_staff_id") REFERENCES "public"."staff"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ptm_schedules" ADD CONSTRAINT "ptm_schedules_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ptm_schedules" ADD CONSTRAINT "ptm_schedules_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ptm_slots" ADD CONSTRAINT "ptm_slots_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ptm_slots" ADD CONSTRAINT "ptm_slots_schedule_id_ptm_schedules_id_fk" FOREIGN KEY ("schedule_id") REFERENCES "public"."ptm_schedules"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ptm_slots" ADD CONSTRAINT "ptm_slots_teacher_staff_id_staff_id_fk" FOREIGN KEY ("teacher_staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "ptm_slots" ADD CONSTRAINT "ptm_slots_booked_by_student_id_students_id_fk" FOREIGN KEY ("booked_by_student_id") REFERENCES "public"."students"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_leaves" ADD CONSTRAINT "staff_leaves_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_leaves" ADD CONSTRAINT "staff_leaves_staff_id_staff_id_fk" FOREIGN KEY ("staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_leaves" ADD CONSTRAINT "staff_leaves_reviewed_by_user_id_app_users_id_fk" FOREIGN KEY ("reviewed_by_user_id") REFERENCES "public"."app_users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_leaves" ADD CONSTRAINT "student_leaves_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_leaves" ADD CONSTRAINT "student_leaves_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_leaves" ADD CONSTRAINT "student_leaves_reviewed_by_staff_id_staff_id_fk" FOREIGN KEY ("reviewed_by_staff_id") REFERENCES "public"."staff"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_transport_allocations" ADD CONSTRAINT "student_transport_allocations_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_transport_allocations" ADD CONSTRAINT "student_transport_allocations_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_transport_allocations" ADD CONSTRAINT "student_transport_allocations_route_id_transport_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."transport_routes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_transport_allocations" ADD CONSTRAINT "student_transport_allocations_stop_id_transport_stops_id_fk" FOREIGN KEY ("stop_id") REFERENCES "public"."transport_stops"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_transport_allocations" ADD CONSTRAINT "student_transport_allocations_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_drivers" ADD CONSTRAINT "transport_drivers_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_logs" ADD CONSTRAINT "transport_logs_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_logs" ADD CONSTRAINT "transport_logs_route_id_transport_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."transport_routes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_logs" ADD CONSTRAINT "transport_logs_current_stop_id_transport_stops_id_fk" FOREIGN KEY ("current_stop_id") REFERENCES "public"."transport_stops"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_routes" ADD CONSTRAINT "transport_routes_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_routes" ADD CONSTRAINT "transport_routes_vehicle_id_transport_vehicles_id_fk" FOREIGN KEY ("vehicle_id") REFERENCES "public"."transport_vehicles"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_routes" ADD CONSTRAINT "transport_routes_driver_id_transport_drivers_id_fk" FOREIGN KEY ("driver_id") REFERENCES "public"."transport_drivers"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_stops" ADD CONSTRAINT "transport_stops_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_stops" ADD CONSTRAINT "transport_stops_route_id_transport_routes_id_fk" FOREIGN KEY ("route_id") REFERENCES "public"."transport_routes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "transport_vehicles" ADD CONSTRAINT "transport_vehicles_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "calendar_events_date_idx" ON "calendar_events" USING btree ("school_id","start_date","end_date");--> statement-breakpoint
CREATE INDEX "calendar_events_type_idx" ON "calendar_events" USING btree ("school_id","event_type");--> statement-breakpoint
CREATE INDEX "issued_cert_student_idx" ON "issued_certificates" USING btree ("school_id","student_id");--> statement-breakpoint
CREATE INDEX "issued_cert_type_idx" ON "issued_certificates" USING btree ("school_id","certificate_type");--> statement-breakpoint
CREATE INDEX "ptm_schedules_date_idx" ON "ptm_schedules" USING btree ("school_id","event_date");--> statement-breakpoint
CREATE INDEX "ptm_slots_sched_teacher_idx" ON "ptm_slots" USING btree ("school_id","schedule_id","teacher_staff_id");--> statement-breakpoint
CREATE INDEX "ptm_slots_student_idx" ON "ptm_slots" USING btree ("school_id","booked_by_student_id");--> statement-breakpoint
CREATE INDEX "staff_leaves_staff_idx" ON "staff_leaves" USING btree ("school_id","staff_id");--> statement-breakpoint
CREATE INDEX "staff_leaves_status_idx" ON "staff_leaves" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "student_leaves_student_idx" ON "student_leaves" USING btree ("school_id","student_id");--> statement-breakpoint
CREATE INDEX "student_leaves_status_idx" ON "student_leaves" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "transport_alloc_student_idx" ON "student_transport_allocations" USING btree ("school_id","student_id");--> statement-breakpoint
CREATE INDEX "transport_alloc_route_idx" ON "student_transport_allocations" USING btree ("school_id","route_id");--> statement-breakpoint
CREATE INDEX "transport_drivers_status_idx" ON "transport_drivers" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "transport_logs_route_date_idx" ON "transport_logs" USING btree ("school_id","route_id","date");--> statement-breakpoint
CREATE INDEX "transport_routes_status_idx" ON "transport_routes" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "transport_stops_route_idx" ON "transport_stops" USING btree ("school_id","route_id","stop_order");--> statement-breakpoint
CREATE INDEX "transport_vehicles_status_idx" ON "transport_vehicles" USING btree ("school_id","status");