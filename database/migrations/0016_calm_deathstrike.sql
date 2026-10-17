CREATE TYPE "public"."risk_alert_status" AS ENUM('active', 'acknowledged', 'resolved');--> statement-breakpoint
CREATE TYPE "public"."risk_level" AS ENUM('low', 'moderate', 'high', 'critical');--> statement-breakpoint
CREATE TABLE "nl_analytics_queries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"user_id" uuid NOT NULL,
	"query" text NOT NULL,
	"intent" text NOT NULL,
	"explanation" text,
	"result_count" integer DEFAULT 0 NOT NULL,
	"executed_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "student_risk_alerts" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"school_id" uuid NOT NULL,
	"student_id" uuid NOT NULL,
	"academic_year_id" uuid NOT NULL,
	"class_id" uuid NOT NULL,
	"section_id" uuid NOT NULL,
	"risk_level" "risk_level" DEFAULT 'moderate' NOT NULL,
	"composite_score" integer NOT NULL,
	"attendance_score" integer NOT NULL,
	"academic_score" integer NOT NULL,
	"fee_score" integer NOT NULL,
	"factors" jsonb NOT NULL,
	"status" "risk_alert_status" DEFAULT 'active' NOT NULL,
	"interventions" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"last_evaluated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "student_risk_alerts_school_id_academic_year_id_student_id_unique" UNIQUE("school_id","academic_year_id","student_id")
);
--> statement-breakpoint
ALTER TABLE "nl_analytics_queries" ADD CONSTRAINT "nl_analytics_queries_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_risk_alerts" ADD CONSTRAINT "student_risk_alerts_school_id_schools_id_fk" FOREIGN KEY ("school_id") REFERENCES "public"."schools"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_risk_alerts" ADD CONSTRAINT "student_risk_alerts_student_id_students_id_fk" FOREIGN KEY ("student_id") REFERENCES "public"."students"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_risk_alerts" ADD CONSTRAINT "student_risk_alerts_academic_year_id_academic_years_id_fk" FOREIGN KEY ("academic_year_id") REFERENCES "public"."academic_years"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_risk_alerts" ADD CONSTRAINT "student_risk_alerts_class_id_classes_id_fk" FOREIGN KEY ("class_id") REFERENCES "public"."classes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "student_risk_alerts" ADD CONSTRAINT "student_risk_alerts_section_id_sections_id_fk" FOREIGN KEY ("section_id") REFERENCES "public"."sections"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "nl_queries_school_idx" ON "nl_analytics_queries" USING btree ("school_id","executed_at");--> statement-breakpoint
CREATE INDEX "student_risk_school_level_idx" ON "student_risk_alerts" USING btree ("school_id","risk_level","status");--> statement-breakpoint
CREATE INDEX "student_risk_section_idx" ON "student_risk_alerts" USING btree ("school_id","section_id","risk_level");--> statement-breakpoint
CREATE INDEX "student_risk_student_idx" ON "student_risk_alerts" USING btree ("school_id","student_id");