import { Link } from "@tanstack/react-router";
import type { ComponentProps, ReactNode } from "react";

type LinkProps = ComponentProps<typeof Link>;

interface AppLinkProps {
  to: string;
  params?: Record<string, string> | undefined;
  className?: string | undefined;
  children: ReactNode;
  activeOptions?: LinkProps["activeOptions"] | undefined;
  "aria-label"?: string | undefined;
  "aria-current"?: ComponentProps<"a">["aria-current"];
}

/**
 * Wrapper de Link para rutas resueltas en tiempo de ejecución
 * (navegación declarativa y métricas con drilldown).
 * Las rutas estáticas deben seguir usando <Link> directamente.
 */
export function AppLink({ to, params, ...rest }: AppLinkProps) {
  const routerProps = { to, params } as unknown as LinkProps;
  return <Link {...routerProps} {...rest} />;
}
