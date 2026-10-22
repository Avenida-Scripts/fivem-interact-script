import React, { useEffect, useState } from "react";
import { fetchNui } from "../utils/fetchNui";

type Element = { label: string };

export type DialogueState = {
  visible:  boolean;
  npcName:  string;
  npcTag:   string;
  message:  string;
  elements: Element[];
};

export const DEFAULT_DIALOGUE: DialogueState = {
  visible:  false,
  npcName:  "",
  npcTag:   "",
  message:  "",
  elements: [],
};

type Props = DialogueState;

// True above 2560×1440 (4K+) : answer boxes look cramped on those resolutions, so their height is
// doubled (see minHeight below). AND on both dimensions = strictly "above 2560×1440".
const useHiRes = (): boolean => {
  const [hi, setHi] = useState(false);
  useEffect(() => {
    const mq = window.matchMedia("(min-width: 2561px) and (min-height: 1441px)");
    const update = () => setHi(mq.matches);
    update();
    mq.addEventListener("change", update);
    return () => mq.removeEventListener("change", update);
  }, []);
  return hi;
};

const Dialogue: React.FC<Props> = ({ visible, npcName, npcTag, message, elements }) => {
  const [hovered, setHovered] = useState<number | null>(null);
  const hiRes = useHiRes();

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape" && visible) {
        fetchNui("dialogClose");
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [visible]);

  return (
    <div
      style={{
        position:       "fixed",
        bottom:         "3rem",
        left:           "50%",
        transform:      "translateX(-50%)",
        width:          "50vw",
        display:        "flex",
        flexDirection:  "column",
        gap:            "1.5rem",
        fontFamily:     "'Poppins', sans-serif",
        opacity:        visible ? 1 : 0,
        pointerEvents:  visible ? "auto" : "none",
        transition:     "opacity 0.3s ease",
        zIndex:         9999,
      }}
    >
      {/* NPC header */}
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: "0.5rem" }}>
        <span
          style={{
            fontSize:   "2rem",
            fontWeight: 700,
            color:      "whitesmoke",
            textShadow:    "2px 2px 2px rgba(0,0,0,1.0)",
            textAlign:     "center",
            fontFamily:    "'Barlow', sans-serif",
            textTransform: "uppercase",
            letterSpacing: "0.1vw",
          }}
        >
          {npcName}
        </span>

        {npcTag && (
          <div style={{ display: "flex", alignItems: "center", gap: "1rem", width: "100%", justifyContent: "center" }}>
            <div style={{ flex: 1, maxWidth: "20%", height: "2px", background: "linear-gradient(to right, transparent, whitesmoke)" }} />
            <span
              style={{
                background:   "#feae00",
                color:        "#000",
                fontWeight:   700,
                fontSize:     "0.75rem",
                padding:      "0.2rem 0.6rem",
                borderRadius: "3px",
                textTransform: "uppercase",
                letterSpacing: "0.08em",
                boxShadow:    "0 4px 10px rgba(0,0,0,.9)",
              }}
            >
              {npcTag}
            </span>
            <div style={{ flex: 1, maxWidth: "20%", height: "2px", background: "linear-gradient(to left, transparent, whitesmoke)" }} />
          </div>
        )}
      </div>

      {/* Message */}
      <div style={{ textAlign: "center" }}>
        <span
          style={{
            fontSize:   "1rem",
            fontWeight: 600,
            color:      "whitesmoke",
            textShadow: "2px 2px 2px rgba(0,0,0,1.0)",
            lineHeight: 1.6,
          }}
        >
          {message}
        </span>
      </div>

      {/* Options */}
      {elements.length > 0 && (
        <div
          style={{
            display:             "grid",
            gridTemplateColumns: "1fr 1fr",
            gap:                 "0.6rem",
          }}
        >
          {elements.map((el, idx) => (
            <div
              key={idx}
              onClick={() => fetchNui("dialogClick", idx)}
              onMouseEnter={() => setHovered(idx)}
              onMouseLeave={() => setHovered(null)}
              style={{
                background:   "linear-gradient(10deg, rgba(0,0,0,.5) 30%, rgba(30,36,46,0) 100%), #171a1f",
                border:       "1px solid #20242b",
                borderRadius: "6px",
                padding:      "0.75rem 1rem",
                boxSizing:    "border-box",
                display:      "flex",
                alignItems:   "center",
                // Above 2560×1440 (4K+) : box height doubled (2.8rem → 5.6rem).
                minHeight:    hiRes ? "5.6rem" : "2.8rem",
                cursor:       "pointer",
                boxShadow:    "0 4px 10px rgba(0,0,0,.9)",
                transition:   "all 0.2s ease",
                color:        hovered === idx ? "#feae00" : "#9095a0",
                transform:    hovered === idx ? "translateY(-4px) scale(1.02)" : "none",
                fontWeight:   600,
                fontSize:     "0.875rem",
                textShadow:   "2px 2px 2px rgba(0,0,0,1.0)",
              }}
            >
              {el.label}
            </div>
          ))}
        </div>
      )}
    </div>
  );
};

export default Dialogue;
