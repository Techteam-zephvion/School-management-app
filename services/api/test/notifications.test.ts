import { describe, expect, it } from 'vitest';
import { NotificationService } from '../src/notifications/notification-service';
import {
  sendNotificationSchema,
  createChatConversationSchema,
  sendChatMessageSchema,
  updateTeacherAvailabilitySchema,
} from '../src/http/validation';

describe('NotificationService', () => {
  const service = new NotificationService();

  it('delivers in_app notifications immediately', async () => {
    const res = await service.dispatch({
      schoolId: '00000000-0000-4000-8000-000000000001',
      recipientUserId: '00000000-0000-4000-8000-000000000002',
      channel: 'in_app',
      title: 'School Notice',
      body: 'Sports day will be held on Friday.',
    });

    expect(res.status).toBe('delivered');
    expect(res.channel).toBe('in_app');
    expect(res.deliveredAt).toBeDefined();
  });

  it('fails SMS/WhatsApp dispatch if recipient phone number is missing', async () => {
    const res = await service.dispatch({
      schoolId: '00000000-0000-4000-8000-000000000001',
      channel: 'sms',
      title: 'Alert',
      body: 'Important message',
    });

    expect(res.status).toBe('failed');
    expect(res.failureReason).toContain('Missing recipient phone number');
  });

  it('successfully delivers SMS and WhatsApp in simulation sandbox mode', async () => {
    const smsRes = await service.dispatch({
      schoolId: '00000000-0000-4000-8000-000000000001',
      recipientPhone: '+919876543210',
      channel: 'sms',
      title: 'Absence Alert',
      body: 'Your child was marked absent today.',
    });
    expect(smsRes.status).toBe('delivered');

    const waRes = await service.dispatch({
      schoolId: '00000000-0000-4000-8000-000000000001',
      recipientPhone: '+919876543210',
      channel: 'whatsapp',
      title: 'Fee Reminder',
      body: 'Tuition fee is due.',
    });
    expect(waRes.status).toBe('delivered');
  });

  describe('formatters', () => {
    it('formats absence alerts accurately', () => {
      const alert = NotificationService.formatAbsenceAlert('Aarav Sharma', '2026-10-16', 'Greenwood High');
      expect(alert.title).toBe('Absence Alert: Aarav Sharma');
      expect(alert.body).toContain('Aarav Sharma was marked absent on 2026-10-16 at Greenwood High');
    });

    it('formats upcoming fee due reminders', () => {
      const reminder = NotificationService.formatFeeReminder(
        'Diya Patel',
        'Term 2 Tuition Fee',
        1500000, // in paise: ₹15,000
        '2026-10-25',
        false,
      );
      expect(reminder.title).toBe('Fee Due Reminder: Diya Patel');
      expect(reminder.body).toContain('₹15,000');
      expect(reminder.body).toContain('due on 2026-10-25');
    });

    it('formats overdue fee notices urgently', () => {
      const overdue = NotificationService.formatFeeReminder(
        'Rohan Kumar',
        'Term 1 Exam Fee',
        500000,
        '2026-10-01',
        true,
      );
      expect(overdue.title).toBe('Overdue Fee Notice: Rohan Kumar');
      expect(overdue.body).toContain('OVERDUE');
      expect(overdue.body).toContain('due on 2026-10-01');
    });

    it('formats homework notices with subject and due date', () => {
      const hw = NotificationService.formatHomeworkNotice(
        'Ananya Sen',
        'Mathematics',
        'Quadratic Equations Worksheet 4',
        '2026-10-18',
      );
      expect(hw.title).toBe('New Homework: Mathematics');
      expect(hw.body).toContain('Quadratic Equations Worksheet 4');
      expect(hw.body).toContain('due on 2026-10-18');
    });
  });
});

describe('Messaging & Availability Schemas', () => {
  const uuid = '00000000-0000-4000-8000-000000000001';

  it('validates sendNotificationSchema', () => {
    const valid = sendNotificationSchema.safeParse({
      channel: 'sms',
      recipientPhone: '+919876543210',
      title: 'Exam Schedule',
      body: 'Mid-term exams commence next Monday.',
    });
    expect(valid.success).toBe(true);
  });

  it('validates createChatConversationSchema', () => {
    const valid = createChatConversationSchema.safeParse({
      studentId: uuid,
      teacherStaffId: uuid,
      subject: 'Inquiry regarding Mathematics homework',
      initialMessage: 'Good evening, could you clarify question 3?',
    });
    expect(valid.success).toBe(true);
  });

  it('validates updateTeacherAvailabilitySchema time formats', () => {
    const valid = updateTeacherAvailabilitySchema.safeParse({
      startTime: '09:00',
      endTime: '16:30',
      availableDays: '1,2,3,4,5',
      autoReplyMessage: 'Outside working hours, will respond soon.',
      isEnabled: true,
    });
    expect(valid.success).toBe(true);

    const invalidTime = updateTeacherAvailabilitySchema.safeParse({
      startTime: '25:00',
      endTime: '16:30',
      availableDays: '1,2,3,4,5',
      autoReplyMessage: 'Hello',
      isEnabled: true,
    });
    expect(invalidTime.success).toBe(false);
  });
});
