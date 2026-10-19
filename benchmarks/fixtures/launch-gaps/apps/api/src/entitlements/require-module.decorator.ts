import { SetMetadata } from '@nestjs/common';

export const REQUIRED_MODULE = 'required_module';

/** Marks a handler or controller as needing a module key or an extension slug. */
export const RequireModule = (module: string) => SetMetadata(REQUIRED_MODULE, module);
