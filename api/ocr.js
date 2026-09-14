import multer from "multer";
import {createWorker} from "tesseract.js";
import {createClient} from "@supabase/supabase-js";
import path from "node:path";
import {fileURLToPath} from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {fileSize: 10 * 1024 * 1024}
});
const supabase = process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY
  ? createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY)
  : null;
let workerPromise;

function runMiddleware(req, res, middleware){
  return new Promise((resolve, reject) => middleware(req, res, error => error ? reject(error) : resolve()));
}

async function getWorker(){
  if (!workerPromise) workerPromise = createWorker("eng", 1, {langPath: path.join(__dirname, ".."), gzip: false});
  return workerPromise;
}

export default async function handler(req, res){
  if (req.method !== "POST") return res.status(405).json({error: "Method not allowed."});
  const token = req.headers.authorization?.replace(/^Bearer\s+/i, "");
  if (process.env.OCR_ALLOW_ANONYMOUS !== "true") {
    if (!supabase) return res.status(500).json({error: "OCR backend is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY in Vercel, then redeploy."});
    if (!token) return res.status(401).json({error: "Sign in before using OCR."});
    const {data, error} = await supabase.auth.getUser(token);
    if (error || !data.user) return res.status(401).json({error: "Your session has expired. Sign in again."});
  }
  try{
    await runMiddleware(req, res, upload.single("image"));
    if (!req.file) return res.status(400).json({error: "An image is required."});
    const worker = await getWorker();
    const recognition = worker.recognize(req.file.buffer);
    const timeout = new Promise((_, reject) => setTimeout(() => reject(new Error("OCR timed out")), 50000));
    const {data} = await Promise.race([recognition, timeout]);
    const words = (data.words || []).map(word => ({
      block: word.block,
      paragraph: word.paragraph,
      line: word.line,
      text: word.text,
      confidence: word.confidence,
      left: word.bbox?.x0,
      top: word.bbox?.y0,
      width: word.bbox ? word.bbox.x1 - word.bbox.x0 : 0,
      height: word.bbox ? word.bbox.y1 - word.bbox.y0 : 0
    }));
    return res.json({text: data.text, tsv: data.tsv || "", words});
  }catch(error){
    console.error("OCR failed", error);
    return res.status(500).json({error: "OCR failed on the server."});
  }
}

export const config = {
  api: {bodyParser: false}
};
