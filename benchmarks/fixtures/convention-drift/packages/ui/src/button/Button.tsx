import type { ButtonHTMLAttributes } from 'react';
import styles from './Button.module.css';

export type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: 'primary' | 'secondary' | 'danger';
};

export function Button({ variant = 'primary', type = 'button', className, ...rest }: ButtonProps) {
  const classes = [styles.button, styles[variant], className].filter(Boolean).join(' ');
  return <button type={type} className={classes} {...rest} />;
}
