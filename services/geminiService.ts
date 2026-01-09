
import { GoogleGenAI, Type } from "@google/genai";
import { Difficulty } from "../types";

const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });

export interface ChainData {
  chain: string[];
  explanations: string[];
}

export const generateWordChainData = async (difficulty: Difficulty): Promise<ChainData> => {
  const complexityMap = {
    'EASY': 'very simple common two-word phrases (e.g., COLD WATER, ICE CREAM)',
    'MEDIUM': 'common idioms and collocations (e.g., SOCIAL MEDIA, FIELD TRIP, HIGH SCHOOL)',
    'HARD': 'complex idioms and abstract connections (e.g., COLD FEET, SILVER LINING, NIGHT OWL)'
  };

  try {
    const response = await ai.models.generateContent({
      model: "gemini-3-flash-preview",
      contents: `Generate an interesting word chain of 9 English words. 
      Difficulty level: ${difficulty}. Use ${complexityMap[difficulty]}.
      Each consecutive pair MUST form a common two-word phrase, idiom, or collocation. 
      CRITICAL RULE: DO NOT split single compound words into two parts (e.g., do not split "SUNFLOWER" into "SUN" and "FLOWER"). 
      Instead, use separate words that form a phrase, like "SUN" and "RAYS" (Sun rays).
      For each pair (8 pairs total), provide a very brief one-sentence explanation of what that phrase means.
      Format the response as JSON. Ensure the JSON is valid and only includes the requested fields.`,
      config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            chain: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
              description: "A list of 9 words.",
            },
            explanations: {
              type: Type.ARRAY,
              items: { type: Type.STRING },
              description: "8 brief explanations.",
            }
          },
          required: ["chain", "explanations"]
        },
      },
    });

    const data = JSON.parse(response.text || '{"chain": [], "explanations": []}');
    if (data.chain?.length >= 9 && data.explanations?.length >= 8) {
      return {
        chain: data.chain.map((w: string) => w.toUpperCase().trim()),
        explanations: data.explanations
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
        "BOOK CLUB: A group of people who meet to discuss books."
      ]
    };
  }
};
