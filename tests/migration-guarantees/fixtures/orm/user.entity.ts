@Entity() @Unique(['email'])
export class User { @Column({ unique: true }) email: string; }
