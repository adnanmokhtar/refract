export class UsersService {
  constructor(private readonly repo: UsersRepository) {}
  async create(dto: CreateUserDto) {
    try { return await this.repo.save(dto); }
    catch (e) { if (e.code === 'P2002') throw new EmailTakenError(dto.email); throw e; }
  }
}
