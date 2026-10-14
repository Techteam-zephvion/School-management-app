CREATE TYPE "public"."fee_allocation_status" AS ENUM('pending', 'partial', 'paid', 'overdue');--> statement-breakpoint
CREATE TYPE "public"."fee_frequency" AS ENUM('one_time', 'term', 'monthly', 'annual');--> statement-breakpoint
CREATE TYPE "public"."fee_payment_method" AS ENUM('cash', 'upi', 'card', 'bank_transfer', 'cheque');--> statement-breakpoint
CREATE TABLE "fee_payments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"allocation_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"receipt_number" text NOT NULL,
	"amount_paid" integer NOT NULL,
	"payment_method" "fee_payment_method" DEFAULT 'cash' NOT NULL,
	"transaction_reference" text,
	"paid_at" timestamp with time zone DEFAULT now() NOT NULL,
	"recorded_by_staff_id" uuid,
	"notes" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "fee_payments_school_id_receipt_number_unique" UNIQUE("school_id","receipt_number")
);
--> statement-breakpoint
CREATE TABLE "fee_structures" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"academic_year_id" uuid NOT NULL,
	"name" text NOT NULL,
	"code" text NOT NULL,
	"description" text,
	"amount" integer NOT NULL,
	"frequency" "fee_frequency" DEFAULT 'term' NOT NULL,
	"due_date" date,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "fee_structures_school_id_academic_year_id_code_unique" UNIQUE("school_id","academic_year_id","code")
);
--> statement-breakpoint
CREATE TABLE "student_fee_allocations" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"fee_structure_id" uuid NOT NULL,
	"academic_year_id" uuid NOT NULL,
	"amount" integer NOT NULL,
	"due_date" date NOT NULL,
	"status" "fee_allocation_status" DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "fee_payments" ADD CONSTRAINT "fee_payments_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_payments" ADD CONSTRAINT "fee_payments_allocation_id_student_fee_allocations_id_fk" FOREIGN KEY ("allocation_id") REFERENCES "public"."student_fee_allocations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_payments" ADD CONSTRAINT "fee_payments_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_payments" ADD CONSTRAINT "fee_payments_recorded_by_staff_id_staff_id_fk" FOREIGN KEY ("recorded_by_staff_id") REFERENCES "public"."staff"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_structures" ADD CONSTRAINT "fee_structures_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "fee_structures" ADD CONSTRAINT "fee_structures_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_fee_allocations" ADD CONSTRAINT "student_fee_allocations_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_fee_allocations" ADD CONSTRAINT "student_fee_allocations_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_fee_allocations" ADD CONSTRAINT "student_fee_allocations_fee_structure_id_fee_structures_id_fk" FOREIGN KEY ("fee_structure_id") REFERENCES "public"."fee_structures"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_fee_allocations" ADD CONSTRAINT "student_fee_allocations_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "fee_payments_student_idx" ON "fee_payments" USING btree ("school_id","student_id","paid_at");--> statement-breakpoint
CREATE INDEX "fee_payments_allocation_idx" ON "fee_payments" USING btree ("school_id","allocation_id");--> statement-breakpoint
CREATE INDEX "fee_structures_school_year_idx" ON "fee_structures" USING btree ("school_id","academic_year_id");--> statement-breakpoint
CREATE INDEX "fee_allocations_student_idx" ON "student_fee_allocations" USING btree ("school_id","student_id");--> statement-breakpoint
CREATE INDEX "fee_allocations_year_status_idx" ON "student_fee_allocations" USING btree ("school_id","academic_year_id","status");