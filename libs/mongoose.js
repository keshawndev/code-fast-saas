import mongoose from "mongoose";
import User from "../models/User";
import Board from "../models/Board";

const connectMongo = () => {
  try {
    mongoose.connect(process.env.MONGO_URI);
  } catch (e) {
    console.error("Mongoos Error: " + e.message);
  }
};

export default connectMongo;
