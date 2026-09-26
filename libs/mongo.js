import { MongoClient, ServerApiVersion } from "mongodb";

const options = {
  serverApi: {
    version: ServerApiVersion.v1,
    strict: true,
    deprecationErrors: true,
  },
};

export default function getMongoClient() {
  if (!process.env.MONGO_URI) {
    throw new Error('Invalid/Missing environment variable: "MONGO_URI"');                              
  }                                                                                                    
  if (!globalThis._mongoClientPromise) {
    const client = new MongoClient(process.env.MONGO_URI, options);
    globalThis._mongoClientPromise = client.connect();
  }

  return globalThis._mongoClientPromise;
}