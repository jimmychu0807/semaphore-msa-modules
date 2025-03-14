import Image from "next/image";

export function Footer() {
  return (
    <footer className="row-start-3 flex gap-6 flex-wrap items-start justify-center min-h-12">
      <a
        className="flex items-center gap-2 hover:underline hover:underline-offset-4"
        href="https://github.com/jimmychu0807/semaphore-msa-modules"
        target="_blank"
        rel="noopener noreferrer"
      >
        <Image aria-hidden src="/window.svg" alt="Window icon" width={16} height={16} />
        Source
      </a>
      <a
        className="flex items-center gap-2 hover:underline hover:underline-offset-4"
        href="https://jimmychu0807.hk/semaphore-msa-modules"
        target="_blank"
        rel="noopener noreferrer"
      >
        <Image aria-hidden src="/file.svg" alt="File icon" width={16} height={16} />
        Blog Post
      </a>
    </footer>
  );
}
