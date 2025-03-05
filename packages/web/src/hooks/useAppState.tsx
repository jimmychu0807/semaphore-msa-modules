"use client";

import { useQuery, useQueryClient, useMutation } from "@tanstack/react-query";

const APP_SCOPE = "semaphore-modules-demo";

export function useAppState(key: string, initVal: unknown = null) {
  return useQuery({
    queryKey: [APP_SCOPE, { key }],
    queryFn: async () => {
      const item = window.localStorage.getItem(key);
      const val = item ? JSON.parse(item) : initVal;
      return val;
    },
  });
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function useMutateAppState(key: string, mutationFunction?: (val: any) => Promise<void>) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn:
      mutationFunction ||
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (async (val: any) => {
        window.localStorage.setItem(key, JSON.stringify(val));
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [APP_SCOPE, { key }] });
    },
  });
}

export function useClearAppState(key: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async () => {
      window.localStorage.removeItem(key);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [APP_SCOPE, { key }] });
    },
  });
}
