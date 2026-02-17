export type AppError =
  | { type: "Validation"; message: string; field?: string }
  | { type: "Auth"; message: string }
  | { type: "NotFound"; resource: string }
  | { type: "Unknown"; message: string };

export type Result<T> = { ok: true; data: T } | { ok: false; error: AppError };

export const ok = <T>(data: T): Result<T> => ({ ok: true, data });

export const fail = (error: AppError): Result<never> => ({
  ok: false,
  error,
});

export type ServiceResult<T> = Promise<Result<T>>;
