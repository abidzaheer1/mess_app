"use client";

import clsx from "clsx";

export default function Icon({
  name,
  className,
  filled,
}: {
  name: string;
  className?: string;
  filled?: boolean;
}) {
  return (
    <span
      className={clsx(
        "material-symbols-outlined select-none align-middle",
        filled && '[fontVariationSettings_"FILL"_1]',
        className,
      )}
      aria-hidden
      style={filled ? { fontVariationSettings: "'FILL' 1, 'wght' 400" } : undefined}
    >
      {name}
    </span>
  );
}
