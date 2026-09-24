// an API endpoint to create a Post document in the database. the route is not protected by the auth middleware, so anyone can create a post. The route exspects a POST request with a title, description in the request body. the boardId is in the query parameters. The userId is populated with the users ID if they are logged in.

import { NextResponse } from "next/server";
import { Filter } from "bad-words";
import connectMongo from "@/libs/mongoose";
import Post from "@/models/Post";
import Board from "@/models/Board";
import User from "@/models/User";
import { auth } from "@/auth";

export async function POST(req) {
  try {
    const body = await req.json();
    const { title, description } = body;
    const { searchParams } = req.nextUrl;
    const boardId = searchParams.get("boardId");
    const BadWordsFilter = new Filter();
    const sanitizedTitle = BadWordsFilter.clean(title);
    const sanitizedDescription = BadWordsFilter.clean(description);

    if (!sanitizedTitle || !sanitizedDescription) {
      return NextResponse.json(
        { error: "Title and description are required" },
        { status: 400 }
      );
    }

    if (!boardId) {
      return NextResponse.json(
        { error: "Board ID is required" },
        { status: 400 }
      );
    }

    const session = await auth();

    await connectMongo();

    const board = await Board.findById(boardId);

    if (!board) {
      return NextResponse.json({ error: "Board not found" }, { status: 404 });
    }

    const post = await Post.create({
      title: sanitizedTitle,
      description: sanitizedDescription,
      boardId,
      userId: session?.user?.id,
    });

    return NextResponse.json({ post });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 500 });
  }
}

export async function DELETE(req) {
  try {
    const { searchParams } = req.nextUrl;
    const postId = searchParams.get("postId");

    if (!postId) {
      return NextResponse.json(
        { error: "Post ID is required" },
        { status: 400 }
      );
    }

    const session = await auth();

    await connectMongo();

    const user = await User.findById(session.user.id);

    if (!user.hasAccess) {
      return NextResponse.json(
        { error: "Please Subscribe first" },
        { status: 403 }
      );
    }

    const post = await Post.findById(postId);

    if (!post) {
      return NextResponse.json({ error: "Post not found" }, { status: 404 });
    }

    if (!user.boards.includes(post.boardId.toString())) {
      return NextResponse.json({ error: "Not Authorized" }, { status: 401 });
    }

    await Post.deleteOne({ _id: postId });

    return NextResponse.json({ message: "Post deleted" });
  } catch (e) {
    return NextResponse.json({ error: e.message }, { status: 500 });
  }
}
