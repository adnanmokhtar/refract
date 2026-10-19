import { Injectable } from '@nestjs/common';
import { EntityManager } from '@mikro-orm/postgresql';

export interface CommentNode {
  id: string;
  authorName: string;
  body: string;
  createdAt: Date;
  replies: CommentNode[];
}

export interface RenderedComment {
  id: string;
  author: string;
  body: string;
  at: string;
}

/** Product Q&A: shoppers reply to replies without any nesting rule, the page shows the thread flattened. */
export function renderThread(node: CommentNode): RenderedComment[] {
  const self: RenderedComment = { id: node.id, author: node.authorName, body: node.body, at: node.createdAt.toISOString() };
  return [self, ...node.replies.flatMap(renderThread)];
}

interface CommentRow {
  id: string;
  reply_to: string | null;
  author_name: string;
  body: string;
  created_at: Date;
}

@Injectable()
export class CommentThreadRenderer {
  constructor(private readonly em: EntityManager) {}

  async threadFor(productId: string): Promise<RenderedComment[]> {
    const rows = await this.em
      .getConnection()
      .execute<CommentRow[]>('SELECT id, reply_to, author_name, body, created_at FROM comments WHERE product_id = ? ORDER BY created_at', [productId]);
    const nodes = new Map<string, CommentNode>();
    for (const r of rows) {
      nodes.set(r.id, { id: r.id, authorName: r.author_name, body: r.body, createdAt: r.created_at, replies: [] });
    }
    const roots: CommentNode[] = [];
    for (const r of rows) {
      const node = nodes.get(r.id)!;
      const owner = r.reply_to ? nodes.get(r.reply_to) : undefined;
      if (owner) owner.replies.push(node);
      else roots.push(node);
    }
    return roots.flatMap(renderThread);
  }
}
