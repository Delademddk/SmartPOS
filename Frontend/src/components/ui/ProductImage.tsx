import { Package } from "lucide-react";
import { cn } from "@/utils/cn";
import { resolveImageUrl } from "@/utils/image";

interface ProductImageProps {
  imageUrl?: string | null;
  alt: string;
  className?: string;
  iconClassName?: string;
}

export function ProductImage({ imageUrl, alt, className, iconClassName }: ProductImageProps) {
  const resolved = resolveImageUrl(imageUrl);

  if (!resolved) {
    return (
      <div
        className={cn(
          "flex items-center justify-center bg-gray-100 text-gray-400",
          className,
        )}
        role="img"
        aria-label={alt}
      >
        <Package aria-hidden="true" className={cn("h-5 w-5", iconClassName)} />
      </div>
    );
  }

  return <img src={resolved} alt={alt} loading="lazy" className={cn("object-cover", className)} />;
}
