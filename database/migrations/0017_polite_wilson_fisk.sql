CREATE TYPE "public"."hostel_room_type" AS ENUM('boys', 'girls', 'staff');--> statement-breakpoint
CREATE TYPE "public"."inventory_category" AS ENUM('lab_equipment', 'sports_gear', 'classroom', 'it_hardware', 'furniture', 'consumables');--> statement-breakpoint
CREATE TYPE "public"."inventory_condition" AS ENUM('good', 'fair', 'maintenance_required', 'damaged', 'disposed');--> statement-breakpoint
CREATE TYPE "public"."inventory_purchase_status" AS ENUM('pending', 'approved', 'ordered', 'received', 'rejected');--> statement-breakpoint
CREATE TYPE "public"."library_book_category" AS ENUM('general', 'science', 'mathematics', 'literature', 'history', 'reference', 'periodical');--> statement-breakpoint
CREATE TYPE "public"."library_loan_status" AS ENUM('issued', 'returned', 'overdue', 'lost');--> statement-breakpoint
CREATE TYPE "public"."payroll_status" AS ENUM('draft', 'processed', 'paid');--> statement-breakpoint
CREATE TYPE "public"."visitor_gate_pass_status" AS ENUM('active', 'checked_out');--> statement-breakpoint
CREATE TABLE "hostel_allocations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"room_id" uuid NOT NULL,
	"bed_number" text NOT NULL,
	"allocated_at" date NOT NULL,
	"vacated_at" date,
	"status" text DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "hostel_rooms" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"block_name" text NOT NULL,
	"room_number" text NOT NULL,
	"room_type" "hostel_room_type" DEFAULT 'boys' NOT NULL,
	"capacity" integer DEFAULT 2 NOT NULL,
	"occupied_count" integer DEFAULT 0 NOT NULL,
	"term_fee" integer DEFAULT 0 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "hostel_rooms_school_id_block_name_room_number_unique" UNIQUE("school_id","block_name","room_number")
);
--> statement-breakpoint
CREATE TABLE "infirmary_visits" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"visited_at" timestamp with time zone DEFAULT now() NOT NULL,
	"symptoms" text NOT NULL,
	"treatment_given" text NOT NULL,
	"attended_by_staff_id" uuid NOT NULL,
	"parent_notified" boolean DEFAULT false NOT NULL,
	"follow_up_needed" boolean DEFAULT false NOT NULL,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "inventory_allocations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"item_id" uuid NOT NULL,
	"allocated_to_staff_id" uuid NOT NULL,
	"purpose" text NOT NULL,
	"quantity" integer DEFAULT 1 NOT NULL,
	"allocated_at" date NOT NULL,
	"returned_at" date,
	"status" text DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "inventory_items" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"item_code" text NOT NULL,
	"name" text NOT NULL,
	"category" "inventory_category" NOT NULL,
	"quantity" integer DEFAULT 1 NOT NULL,
	"available_quantity" integer DEFAULT 1 NOT NULL,
	"unit" text DEFAULT 'pcs' NOT NULL,
	"condition" "inventory_condition" DEFAULT 'good' NOT NULL,
	"room_location" text NOT NULL,
	"purchase_cost" integer,
	"purchase_date" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "inventory_items_school_id_item_code_unique" UNIQUE("school_id","item_code")
);
--> statement-breakpoint
CREATE TABLE "inventory_purchase_requests" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"item_name" text NOT NULL,
	"category" "inventory_category" NOT NULL,
	"quantity" integer DEFAULT 1 NOT NULL,
	"estimated_cost" integer NOT NULL,
	"requested_by_staff_id" uuid NOT NULL,
	"status" "inventory_purchase_status" DEFAULT 'pending' NOT NULL,
	"review_notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "library_books" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"isbn" text,
	"title" text NOT NULL,
	"author" text NOT NULL,
	"publisher" text,
	"published_year" integer,
	"category" "library_book_category" DEFAULT 'general' NOT NULL,
	"shelf_location" text NOT NULL,
	"total_copies" integer DEFAULT 1 NOT NULL,
	"available_copies" integer DEFAULT 1 NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "library_loans" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"book_id" uuid NOT NULL,
	"member_type" text NOT NULL,
	"member_id" uuid NOT NULL,
	"issued_at" date NOT NULL,
	"due_date" date NOT NULL,
	"returned_at" date,
	"fine_amount" integer DEFAULT 0 NOT NULL,
	"fine_paid" boolean DEFAULT false NOT NULL,
	"status" "library_loan_status" DEFAULT 'issued' NOT NULL,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "library_reservations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"book_id" uuid NOT NULL,
	"member_type" text NOT NULL,
	"member_id" uuid NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"reserved_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "staff_payroll_records" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"staff_id" uuid NOT NULL,
	"academic_year_id" uuid,
	"month" integer NOT NULL,
	"year" integer NOT NULL,
	"basic_salary" integer NOT NULL,
	"allowances" integer DEFAULT 0 NOT NULL,
	"deductions" integer DEFAULT 0 NOT NULL,
	"net_salary" integer NOT NULL,
	"status" "payroll_status" DEFAULT 'draft' NOT NULL,
	"paid_on" date,
	"payment_reference" text,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "staff_payroll_records_school_id_staff_id_month_year_unique" UNIQUE("school_id","staff_id","month","year")
);
--> statement-breakpoint
CREATE TABLE "staff_salary_structures" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"staff_id" uuid NOT NULL,
	"basic_salary" integer NOT NULL,
	"hra" integer DEFAULT 0 NOT NULL,
	"allowances" integer DEFAULT 0 NOT NULL,
	"pf_deduction" integer DEFAULT 0 NOT NULL,
	"esi_deduction" integer DEFAULT 0 NOT NULL,
	"tds_deduction" integer DEFAULT 0 NOT NULL,
	"net_salary" integer NOT NULL,
	"effective_from" date NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "staff_salary_structures_school_id_staff_id_unique" UNIQUE("school_id","staff_id")
);
--> statement-breakpoint
CREATE TABLE "student_health_profiles" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"blood_group" text NOT NULL,
	"allergies" text,
	"chronic_conditions" text,
	"emergency_contact_name" text NOT NULL,
	"emergency_contact_phone" text NOT NULL,
	"doctor_notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "student_health_profiles_school_id_student_id_unique" UNIQUE("school_id","student_id")
);
--> statement-breakpoint
CREATE TABLE "visitor_gate_passes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"visitor_name" text NOT NULL,
	"phone" text NOT NULL,
	"purpose" text NOT NULL,
	"person_to_visit_type" text NOT NULL,
	"person_to_visit_id" uuid,
	"check_in_at" timestamp with time zone DEFAULT now() NOT NULL,
	"check_out_at" timestamp with time zone,
	"badge_number" text NOT NULL,
	"vehicle_number" text,
	"status" "visitor_gate_pass_status" DEFAULT 'active' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "hostel_allocations" ADD CONSTRAINT "hostel_allocations_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "hostel_allocations" ADD CONSTRAINT "hostel_allocations_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "hostel_allocations" ADD CONSTRAINT "hostel_allocations_room_id_hostel_rooms_id_fk" FOREIGN KEY ("room_id") REFERENCES "public"."hostel_rooms"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "hostel_rooms" ADD CONSTRAINT "hostel_rooms_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "infirmary_visits" ADD CONSTRAINT "infirmary_visits_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "infirmary_visits" ADD CONSTRAINT "infirmary_visits_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "infirmary_visits" ADD CONSTRAINT "infirmary_visits_attended_by_staff_id_staff_id_fk" FOREIGN KEY ("attended_by_staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "inventory_allocations" ADD CONSTRAINT "inventory_allocations_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "inventory_allocations" ADD CONSTRAINT "inventory_allocations_item_id_inventory_items_id_fk" FOREIGN KEY ("item_id") REFERENCES "public"."inventory_items"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "inventory_allocations" ADD CONSTRAINT "inventory_allocations_allocated_to_staff_id_staff_id_fk" FOREIGN KEY ("allocated_to_staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "inventory_items" ADD CONSTRAINT "inventory_items_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "inventory_purchase_requests" ADD CONSTRAINT "inventory_purchase_requests_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "inventory_purchase_requests" ADD CONSTRAINT "inventory_purchase_requests_requested_by_staff_id_staff_id_fk" FOREIGN KEY ("requested_by_staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "library_books" ADD CONSTRAINT "library_books_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "library_loans" ADD CONSTRAINT "library_loans_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "library_loans" ADD CONSTRAINT "library_loans_book_id_library_books_id_fk" FOREIGN KEY ("book_id") REFERENCES "public"."library_books"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "library_reservations" ADD CONSTRAINT "library_reservations_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "library_reservations" ADD CONSTRAINT "library_reservations_book_id_library_books_id_fk" FOREIGN KEY ("book_id") REFERENCES "public"."library_books"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_payroll_records" ADD CONSTRAINT "staff_payroll_records_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_payroll_records" ADD CONSTRAINT "staff_payroll_records_staff_id_staff_id_fk" FOREIGN KEY ("staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_payroll_records" ADD CONSTRAINT "staff_payroll_records_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_salary_structures" ADD CONSTRAINT "staff_salary_structures_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "staff_salary_structures" ADD CONSTRAINT "staff_salary_structures_staff_id_staff_id_fk" FOREIGN KEY ("staff_id") REFERENCES "public"."staff"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_health_profiles" ADD CONSTRAINT "student_health_profiles_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_health_profiles" ADD CONSTRAINT "student_health_profiles_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "visitor_gate_passes" ADD CONSTRAINT "visitor_gate_passes_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "hostel_alloc_school_student_idx" ON "hostel_allocations" USING btree ("school_id","student_id","status");--> statement-breakpoint
CREATE INDEX "hostel_alloc_room_idx" ON "hostel_allocations" USING btree ("school_id","room_id");--> statement-breakpoint
CREATE INDEX "hostel_rooms_school_type_idx" ON "hostel_rooms" USING btree ("school_id","room_type");--> statement-breakpoint
CREATE INDEX "infirmary_visits_school_student_idx" ON "infirmary_visits" USING btree ("school_id","student_id","visited_at");--> statement-breakpoint
CREATE INDEX "inv_alloc_school_status_idx" ON "inventory_allocations" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "inv_alloc_staff_idx" ON "inventory_allocations" USING btree ("school_id","allocated_to_staff_id");--> statement-breakpoint
CREATE INDEX "inventory_items_school_cat_idx" ON "inventory_items" USING btree ("school_id","category");--> statement-breakpoint
CREATE INDEX "inv_req_school_status_idx" ON "inventory_purchase_requests" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "inv_req_staff_idx" ON "inventory_purchase_requests" USING btree ("school_id","requested_by_staff_id");--> statement-breakpoint
CREATE INDEX "library_books_school_cat_idx" ON "library_books" USING btree ("school_id","category");--> statement-breakpoint
CREATE INDEX "library_books_school_title_idx" ON "library_books" USING btree ("school_id","title");--> statement-breakpoint
CREATE INDEX "library_loans_school_status_idx" ON "library_loans" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "library_loans_member_idx" ON "library_loans" USING btree ("school_id","member_type","member_id");--> statement-breakpoint
CREATE INDEX "library_loans_book_idx" ON "library_loans" USING btree ("school_id","book_id");--> statement-breakpoint
CREATE INDEX "library_res_school_status_idx" ON "library_reservations" USING btree ("school_id","status");--> statement-breakpoint
CREATE INDEX "library_res_book_idx" ON "library_reservations" USING btree ("school_id","book_id");--> statement-breakpoint
CREATE INDEX "payroll_records_school_period_idx" ON "staff_payroll_records" USING btree ("school_id","year","month","status");--> statement-breakpoint
CREATE INDEX "salary_structures_school_staff_idx" ON "staff_salary_structures" USING btree ("school_id","staff_id");--> statement-breakpoint
CREATE INDEX "health_profiles_school_blood_idx" ON "student_health_profiles" USING btree ("school_id","blood_group");--> statement-breakpoint
CREATE INDEX "visitor_passes_school_status_idx" ON "visitor_gate_passes" USING btree ("school_id","status","check_in_at");