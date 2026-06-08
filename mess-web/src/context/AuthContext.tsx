"use client";

import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signOut as firebaseSignOut,
  type User,
} from "firebase/auth";
import type { UserProfile } from "@/lib/types";
import { ensureUserBasics, fetchUserProfile } from "@/lib/db";
import { getFirebaseAuth } from "@/lib/firebase";
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";

interface AuthState {
  firebaseUser: User | null;
  profile: UserProfile | null;
  loading: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  register: (email: string, password: string) => Promise<void>;
  signOutUser: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [firebaseUser, setFirebaseUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  const refreshProfile = useCallback(async () => {
    const auth = getFirebaseAuth();
    const u = auth.currentUser;
    if (!u) {
      setProfile(null);
      return;
    }
    const p = await fetchUserProfile(u.uid);
    setProfile(p);
  }, []);

  useEffect(() => {
    const auth = getFirebaseAuth();
    const unsub = onAuthStateChanged(auth, async (u) => {
      setFirebaseUser(u);
      if (u) {
        await ensureUserBasics(u.uid, u.email ?? "");
        await refreshProfile();
      } else {
        setProfile(null);
      }
      setLoading(false);
    });
    return () => unsub();
  }, [refreshProfile]);

  const signIn = useCallback(async (email: string, password: string) => {
    await signInWithEmailAndPassword(getFirebaseAuth(), email.trim(), password);
    await refreshProfile();
  }, [refreshProfile]);

  const register = useCallback(async (email: string, password: string) => {
    const cred = await createUserWithEmailAndPassword(getFirebaseAuth(), email.trim(), password);
    await ensureUserBasics(cred.user.uid, cred.user.email ?? "");
    await refreshProfile();
  }, [refreshProfile]);

  const signOutUser = useCallback(async () => {
    await firebaseSignOut(getFirebaseAuth());
    setProfile(null);
  }, []);

  const value = useMemo(
    () => ({
      firebaseUser,
      profile,
      loading,
      signIn,
      register,
      signOutUser,
      refreshProfile,
    }),
    [firebaseUser, profile, loading, signIn, register, signOutUser, refreshProfile],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
