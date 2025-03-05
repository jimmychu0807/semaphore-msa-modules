import { type MouseEvent } from "react";
import { LoadingSpinner } from "./LoadingSpinner";

export function Button({
  buttonText,
  onClick,
  isLoading,
  disabled,
  isSubmit,
}: {
  buttonText: string;
  onClick: (ev: MouseEvent<HTMLElement>) => void;
  isLoading?: boolean;
  disabled?: boolean;
  isSubmit?: boolean;
}) {
  return (
    <button
      className="rounded-full border border-solid border-black/[.08] dark:border-white/[.145] transition-colors flex items-center justify-center hover:bg-[#f2f2f2] dark:hover:bg-[#1a1a1a] hover:border-black/40 text-sm! sm:text-base h-8 sm:h-12 px-2 sm:px-5 sm:min-w-44 font-[family-name:var(--font-geist-mono)]"
      onClick={onClick}
      type={isSubmit ? "submit" : "button"}
      disabled={isLoading || disabled}
    >
      {isLoading ? <LoadingSpinner /> : buttonText}
    </button>
  );
}
