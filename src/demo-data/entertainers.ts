import { Entertainer, EntertainerType } from "@/types";

export const entertainers: Record<string, Entertainer> = {
  "0.0.111": {
    name: "Phish",
    type: EntertainerType.Music,
    description: "Phish will embark on a 23-date Summer Tour beginning July 11 and culminating with their traditional Labor Day Weekend run at Dick's Sporting Goods Park in Commerce City, CO, where they'll return for four nights. The tour includes a seven-night run at New York City's Madison Square Garden.",
    currentIteration: "Summer Tour 2023",
  },
  "0.0.222": {
    name: "Kansas City Chiefs",
    type: EntertainerType.Sports,
    description: "Head Coach Andy Reid leads the returning Super Bowl champion Kansas City Chiefs into the 2023 season captained by the top quarterback in the NFL, Patrick Mahomes.",
    currentIteration: "2023 NFL Season"
  },
  "0.0.333": {
    name: "Tim Heidecker",
    type: EntertainerType.Comedy,
    description: "Tim Heidecker is bringing his \"No More Bullshit\" stand-up character as well as The Very Good Band (with fan favorite Vic Berger) back to the USA for a brand new Summer Tour!",
    currentIteration: "The Two Tims Summer Tour '23",
  },
};
