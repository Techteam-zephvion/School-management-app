-- Phase 1: shared enum types used across the schema (doc 05 §1)
create extension if not exists pgcrypto;

create type app_role as enum ('super_admin', 'school_admin', 'teacher', 'parent');
create type member_status as enum ('invited', 'active', 'suspended');
create type gender as enum ('male', 'female', 'other');
create type enroll_status as enum ('active', 'inactive', 'transferred', 'graduated');
create type attend_status as enum ('present', 'absent', 'late', 'excused', 'holiday');
create type invoice_status as enum ('unpaid', 'partial', 'paid', 'overdue', 'cancelled');
create type payment_status as enum ('created', 'pending', 'captured', 'failed', 'refunded');
create type leave_status as enum ('pending', 'approved', 'rejected', 'cancelled');
create type notice_audience as enum ('school', 'class', 'section', 'individual');
create type notif_type as enum ('attendance', 'homework', 'notice', 'fee', 'result', 'message', 'leave', 'system');
