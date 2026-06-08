export type MemberRole = "admin" | "member";

export interface UserProfile {
  uid: string;
  email: string;
  displayName: string;
  phone?: string;
  dateOfBirth?: string;
  photoURL?: string;
  messId: string | null;
  role: MemberRole | null;
  profileComplete: boolean;
}

export interface Mess {
  id: string;
  name: string;
  inviteCode: string;
  createdBy: string;
  createdAt: number;
  currentDuty?: DutyInfo | null;
}

export interface DutyInfo {
  assigneeUid: string;
  assigneeName: string;
  type: string;
  description: string;
  date: string;
}

export interface Member {
  uid: string;
  displayName: string;
  photoURL?: string;
  role: MemberRole;
  joinedAt: number;
}

export type ExpenseStatus = "paid" | "pending";

export interface Expense {
  id: string;
  title: string;
  amount: number;
  category: string;
  paidByUid: string;
  paidByName: string;
  status: ExpenseStatus;
  createdAt: number;
  expenseDate: string;
}
