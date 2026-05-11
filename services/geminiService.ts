
import { Difficulty } from "../types";

const DEEPSEEK_API_URL = "https://api.deepseek.com/v1/chat/completions";

export interface ChainData {
  chain: string[];
  explanations: string[];
}

const complexityMap = {
  'EASY': 'very simple common two-word phrases (e.g., COLD WATER, ICE CREAM)',
  'MEDIUM': 'common idioms and collocations (e.g., SOCIAL MEDIA, FIELD TRIP, HIGH SCHOOL)',
  'HARD': 'complex idioms and abstract connections (e.g., COLD FEET, SILVER LINING, NIGHT OWL)'
};

export const generateWordChainData = async (difficulty: Difficulty): Promise<ChainData> => {
  try {
    const response = await fetch(DEEPSEEK_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${process.env.DEEPSEEK_API_KEY}`,
      },
      body: JSON.stringify({
        model: "deepseek-chat",
        messages: [{
          role: "user",
          content: `Generate an interesting word chain of 9 English words.
Difficulty level: ${difficulty}. Use ${complexityMap[difficulty]}.
Each consecutive pair MUST form a common two-word phrase, idiom, or collocation.
CRITICAL RULE: DO NOT split single compound words into two parts (e.g., do not split "SUNFLOWER" into "SUN" and "FLOWER").
Instead, use separate words that form a phrase, like "SUN" and "RAYS" (Sun rays).
For each pair (8 pairs total), provide a very brief one-sentence explanation of what that phrase means.
Respond with valid JSON only, no markdown, in this exact format:
{"chain":["WORD1","WORD2","WORD3","WORD4","WORD5","WORD6","WORD7","WORD8","WORD9"],"explanations":["WORD1 WORD2: explanation.","WORD2 WORD3: explanation.","WORD3 WORD4: explanation.","WORD4 WORD5: explanation.","WORD5 WORD6: explanation.","WORD6 WORD7: explanation.","WORD7 WORD8: explanation.","WORD8 WORD9: explanation."]}`,
        }],
        response_format: { type: "json_object" },
      }),
    });

    if (!response.ok) throw new Error(`DeepSeek error: ${response.status}`);

    const json = await response.json();
    const data = JSON.parse(json.choices[0].message.content);

    if (data.chain?.length >= 9 && data.explanations?.length >= 8) {
      return {
        chain: data.chain.map((w: string) => w.toUpperCase().trim()),
        explanations: data.explanations,
      };
    }
    throw new Error("Invalid data format");
  } catch (error) {
    console.error("Error generating chain:", error);
    // Fallback data for stability
    return {
      chain: ["ICE", "CREAM", "SODA", "WATER", "BOTTLE", "CAP", "TAIN", "COOK", "BOOK"],
      explanations: [
        "ICE CREAM: A frozen dessert.",
        "CREAM SODA: A sweet carbonated drink.",
        "SODA WATER: Carbonated water.",
        "WATER BOTTLE: A container for holding water.",
        "BOTTLE CAP: A closure for a bottle.",
        "CAPTAIN COOK: A famous explorer.",
        "COOK BOOK: A book containing recipes.",
        "BOOK CLUB: A group of people who meet to discuss books.",
      ],
    };
  }
};
