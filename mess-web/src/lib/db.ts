import {
  addDoc,
  collection,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  setDoc,
  type Transaction,
  updateDoc,
  writeBatch,
} from "firebase/firestore";
import type { DutyInfo, Expense, Member, Mess, UserProfile } from "@/lib/types";
import { getFirebaseDb } from "@/lib/firebase";

function genInviteCode(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let s = "";
  for (let i = 0; i < 6; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

export async function fetchUserProfile(uid: string): Promise<UserProfile | null> {
  const snap = await getDoc(doc(getFirebaseDb(), "users", uid));
  if (!snap.exists()) return null;
  return snap.data() as UserProfile;
}

export async function ensureUserBasics(uid: string, email: string): Promise<void> {
  const db = getFirebaseDb();
  const ref = doc(db, "users", uid);
  const snap = await getDoc(ref);
  if (snap.exists()) return;
  const base: UserProfile = {
    uid,
    email,
    displayName: email.split("@")[0] ?? "Member",
    messId: null,
    role: null,
    profileComplete: false,
  };
  await setDoc(ref, base);
}

export async function saveUserProfile(
  uid: string,
  partial: Partial<Pick<UserProfile, "displayName" | "phone" | "dateOfBirth" | "profileComplete">>,
): Promise<void> {
  await updateDoc(doc(getFirebaseDb(), "users", uid), { ...partial });
}

async function allocateInvite(tx: Transaction): Promise<string> {
  const db = getFirebaseDb();
  for (let i = 0; i < 12; i++) {
    const code = genInviteCode();
    const inviteRef = doc(db, "messInvites", code);
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists()) return code;
  }
  throw new Error("Could not allocate invite code.");
}

export async function createMess(
  uid: string,
  userName: string,
  name: string,
): Promise<{ messId: string; inviteCode: string }> {
  const db = getFirebaseDb();

  let result: { messId: string; inviteCode: string } | undefined;

  for (let attempt = 0; attempt < 8; attempt++) {
    const messRef = doc(collection(db, "messes"));
    try {
      await runTransaction(db, async (tx) => {
        const inviteCode = await allocateInvite(tx);

        tx.set(messRef, {
          name,
          inviteCode,
          createdBy: uid,
          createdAt: Date.now(),
          currentDuty: null,
        });

        tx.set(doc(db, "messInvites", inviteCode), {
          messId: messRef.id,
          createdBy: uid,
          createdAt: Date.now(),
        });

        tx.set(doc(db, "messes", messRef.id, "members", uid), {
          uid,
          displayName: userName,
          role: "admin",
          joinedAt: Date.now(),
        });

        tx.set(
          doc(db, "users", uid),
          {
            messId: messRef.id,
            role: "admin",
          },
          { merge: true },
        );

        result = { messId: messRef.id, inviteCode };
      });
      break;
    } catch {
      /* retry on contention */
    }
  }

  if (!result) throw new Error("Failed to create mess. Try again.");
  return result;
}

export async function joinMess(uid: string, userName: string, codeRaw: string): Promise<string> {
  const db = getFirebaseDb();
  const code = codeRaw.trim().toUpperCase();

  const inviteSnap = await getDoc(doc(db, "messInvites", code));
  if (!inviteSnap.exists()) throw new Error("Invalid invite code.");
  const { messId } = inviteSnap.data() as { messId: string };

  const batch = writeBatch(db);
  const memberRef = doc(db, "messes", messId, "members", uid);
  const memberSnap = await getDoc(memberRef);
  if (memberSnap.exists()) {
    batch.set(
      doc(db, "users", uid),
      { messId, role: (memberSnap.data() as Member).role },
      { merge: true },
    );
    await batch.commit();
    return messId;
  }

  batch.set(memberRef, {
    uid,
    displayName: userName,
    role: "member",
    joinedAt: Date.now(),
  });

  batch.set(
    doc(db, "users", uid),
    {
      messId,
      role: "member",
    },
    { merge: true },
  );

  await batch.commit();
  return messId;
}

export async function fetchMess(messId: string): Promise<Mess | null> {
  const snap = await getDoc(doc(getFirebaseDb(), "messes", messId));
  if (!snap.exists()) return null;
  return { id: snap.id, ...(snap.data() as Omit<Mess, "id">) };
}

export async function fetchMembers(messId: string): Promise<Member[]> {
  const q = query(collection(getFirebaseDb(), "messes", messId, "members"));
  const snaps = await getDocs(q);
  return snaps.docs.map((d) => d.data() as Member);
}

export async function fetchExpenses(messId: string): Promise<Expense[]> {
  const q = query(
    collection(getFirebaseDb(), "messes", messId, "expenses"),
    orderBy("createdAt", "desc"),
    limit(200),
  );
  const snaps = await getDocs(q);
  return snaps.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Expense, "id">) }));
}

export async function createExpense(
  messId: string,
  expense: Omit<Expense, "id" | "createdAt">,
): Promise<void> {
  await addDoc(collection(getFirebaseDb(), "messes", messId, "expenses"), {
    ...expense,
    createdAt: Date.now(),
  });
}

export async function updateMemberRole(messId: string, uid: string, role: Member["role"]): Promise<void> {
  await updateDoc(doc(getFirebaseDb(), "messes", messId, "members", uid), { role });
}

export async function updateMessDuty(messId: string, duty: DutyInfo | null): Promise<void> {
  await updateDoc(doc(getFirebaseDb(), "messes", messId), {
    currentDuty: duty,
  });
}
