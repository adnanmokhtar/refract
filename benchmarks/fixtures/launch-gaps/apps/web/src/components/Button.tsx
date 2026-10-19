import type { ButtonHTMLAttributes } from 'react';

export function Button(props: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: 'primary' | 'secondary' | 'danger' }) {
  const { variant = 'primary', className, ...rest } = props;
  return <button type="button" className={`btn btn-${variant} ${className ?? ''}`} {...rest} />;
}
