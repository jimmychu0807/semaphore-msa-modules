"use client";

import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";

const APP_SCOPE = "semaphore-modules-demo";

export function useAppState(key: string) {
  return useQuery({
    queryKey: [APP_SCOPE, { key }],
    queryFn: fetchAppState,
  });
}

export function useMutateAppState(key: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (val: unknown) => window.localStorage.setItem(key, JSON.stringify(val)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [APP_SCOPE, { key }] });
    },
  });
}

export function useClearAppState(key: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: () => window.localStorage.removeItem(key),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [APP_SCOPE, { key }] });
    },
  });
}

async function fetchAppState({ queryKey }) {
  const key = queryKey[1].key!;
  const item = window.localStorage.getItem(key);
  const val = item ? JSON.parse(item) : null;
  return val;
}
