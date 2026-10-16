CREATE TYPE "public"."payment_order_status" AS ENUM('ACTIVE', 'PAID', 'EXPIRED', 'FAILED');--> statement-breakpoint
CREATE TABLE "payment_orders" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"allocation_id" uuid NOT NULL,
	"gateway" text DEFAULT 'cashfree' NOT NULL,
	"gateway_order_id" text NOT NULL,
	"payment_session_id" text NOT NULL,
	"amount" integer NOT NULL,
	"currency" text DEFAULT 'INR' NOT NULL,
	"status" "payment_order_status" DEFAULT 'ACTIVE' NOT NULL,
	"cf_payment_id" text,
	"payment_method" text,
	"failure_reason" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "payment_orders_gateway_order_id_unique" UNIQUE("gateway_order_id")
);
--> statement-breakpoint
CREATE TABLE "payment_webhook_events" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"gateway" text DEFAULT 'cashfree' NOT NULL,
	"event_id" text NOT NULL,
	"event_type" text NOT NULL,
	"payload" jsonb NOT NULL,
	"processed_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "payment_webhook_events_event_id_unique" UNIQUE("event_id")
);
--> statement-breakpoint
ALTER TABLE "admission_documents" ADD COLUMN "file_key" text;--> statement-breakpoint
ALTER TABLE "admission_documents" ADD COLUMN "file_url" text;--> statement-breakpoint
ALTER TABLE "admission_documents" ADD COLUMN "file_name" text;--> statement-breakpoint
ALTER TABLE "admission_documents" ADD COLUMN "file_size" integer;--> statement-breakpoint
ALTER TABLE "admission_documents" ADD COLUMN "mime_type" text;--> statement-breakpoint
ALTER TABLE "payment_orders" ADD CONSTRAINT "payment_orders_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payment_orders" ADD CONSTRAINT "payment_orders_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "payment_orders" ADD CONSTRAINT "payment_orders_allocation_id_student_fee_allocations_id_fk" FOREIGN KEY ("allocation_id") REFERENCES "public"."student_fee_allocations"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "payment_orders_student_idx" ON "payment_orders" USING btree ("school_id","student_id");--> statement-breakpoint
CREATE INDEX "payment_orders_allocation_idx" ON "payment_orders" USING btree ("allocation_id");