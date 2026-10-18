import type { ComponentType } from 'react';
import styles from './IconButton.module.css';

export type IconButtonProps = {
  icon: ComponentType<{ 'aria-hidden'?: boolean }>;
  /** Always pass it: it becomes the button's accessible name. */
  label?: string;
  onClick?: () => void;
};

export function IconButton({ icon: Icon, label, onClick }: IconButtonProps) {
  return (
    <button type="button" className={styles.iconButton} aria-label={label} onClick={onClick}>
      <Icon aria-hidden />
    </button>
  );
}
