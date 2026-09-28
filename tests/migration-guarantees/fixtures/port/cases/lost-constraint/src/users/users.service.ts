export class UsersService {
  constructor(private readonly repo: UsersRepository) {}
  async create(dto: CreateUserDto) { return this.repo.save(dto); }
}
