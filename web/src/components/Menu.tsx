import React from "react";
import { cn } from "@/lib/utils";
import { HintIcons } from "../utils/hintIcons";

export type Choice = { bind: string; message: string; hintColor?: string };

export type InteractionProps = {
  visible: boolean;
  message: string;
  bind: string;
  useOnlyBind?: boolean;
  hintOnly?: boolean;
  hintIcon?: string;
  hintColor?: string;
  flash?: boolean;
  choices?: Choice[];
};

const MSG_STYLE: React.CSSProperties = {
  color:         "#ffffff",
  fontWeight:    600,
  fontSize:      "37px",
  lineHeight:    1,
  letterSpacing: "0.03em",
  textTransform: "uppercase",
  textShadow:    "0 3px 8px rgba(0,0,0,0.95), 0 0 4px rgba(0,0,0,0.85)",
  whiteSpace:    "nowrap",
};

// Shared keycap style (white letter, no background)
const KEYCAP_BASE: React.CSSProperties = {
  display:        "inline-flex",
  alignItems:     "center",
  justifyContent: "center",
  minWidth:       "40px",
  color:          "#ffffff",
  fontWeight:     700,
  fontSize:       "42px",
  lineHeight:     1,
  textShadow:     "0 3px 6px rgba(0,0,0,0.95)",
};

// Key — no background, just a tinted separator (border-right) and a white letter
const KeyCap: React.FC<{ value: string; color: string; separator?: boolean }> = ({ value, color, separator = true }) => (
  <span
    style={{
      ...KEYCAP_BASE,
      flexShrink:   0,
      paddingRight: separator ? "15px" : "0",
      borderRight:  separator ? `5px solid ${color}` : "none",
    }}
  >
    {value}
  </span>
);

// One interaction row : [key] | message
const ChoiceRow: React.FC<{ bind: string; message: string; color: string }> = ({ bind, message, color }) => (
  <div style={{ display: "flex", alignItems: "center", gap: "15px" }}>
    <KeyCap value={bind || "E"} color={color} />
    <span style={MSG_STYLE}>{message}</span>
  </div>
);

/**
 * Presentational content (no fixed positioning).
 * The icon is the in-flow element → its center anchors the world point.
 * The label / choice list is absolutely positioned TO THE RIGHT of the icon,
 * so the icon never moves between the hint state and the hold state.
 */
export const InteractionContent: React.FC<InteractionProps> = ({
  message,
  bind,
  useOnlyBind = false,
  hintOnly = false,
  hintIcon = "pin",
  hintColor = "#ffffff",
  flash = false,
  choices,
}) => {
  const HintCmp    = HintIcons[hintIcon] ?? null;
  const hasChoices = !!(choices && choices.length > 0);
  const showText   = !hintOnly; // text only shows in the hold state (close range)

  return (
    <div style={{ position: "relative", display: "inline-flex", alignItems: "center", fontFamily: "'Montserrat', sans-serif" }}>
      {/* Icon — always visible, anchored on the point */}
      <div
        className={cn(flash && "interact-flash")}
        style={{
          display: "flex",
          color:   hintColor,
          filter:  "drop-shadow(0 2px 8px rgba(0,0,0,0.95))",
        }}
      >
        {HintCmp
          ? <HintCmp size={64} />
          : <span style={{ fontSize: "4rem", lineHeight: 1, userSelect: "none" }}>{hintIcon}</span>}
      </div>

      {/* Label / Choices — right of the icon, fades between hint and hold */}
      <div
        style={{
          position:        "absolute",
          left:            "100%",
          top:             "50%",
          marginLeft:      "38px",
          transformOrigin: "left center",
          // Left-to-right reveal : the text "comes out" of the icon (and retracts on the way back).
          // Horizontal insets are negative (-15%) so the text/shadow is never clipped at rest.
          transform:       showText ? "translateY(-50%) translateX(0)" : "translateY(-50%) translateX(-10px)",
          opacity:         showText ? 1 : 0,
          clipPath:        showText ? "inset(-60% -15% -60% -15%)" : "inset(-60% 100% -60% -15%)",
          transition:      "clip-path 0.42s cubic-bezier(0.22,1,0.36,1), transform 0.42s cubic-bezier(0.22,1,0.36,1), opacity 0.28s ease",
          willChange:      "clip-path, transform, opacity",
          pointerEvents:   "none",
          userSelect:      "none",
        }}
      >
        {hasChoices ? (
          // 2-column grid : every message stays aligned whatever the key width is
          <div
            style={{
              display:             "grid",
              gridTemplateColumns: "auto 1fr",
              columnGap:           "15px",
              rowGap:              "17px",
              alignItems:          "center",
            }}
          >
            {choices!.map((c, i) => {
              const color = c.hintColor || hintColor;
              return (
                <React.Fragment key={i}>
                  <span style={{ ...KEYCAP_BASE, display: "flex", height: "100%", paddingRight: "15px", borderRight: `5px solid ${color}` }}>
                    {c.bind || "E"}
                  </span>
                  <span style={MSG_STYLE}>{c.message}</span>
                </React.Fragment>
              );
            })}
          </div>
        ) : useOnlyBind ? (
          <KeyCap value={bind || "E"} color={hintColor} separator={false} />
        ) : (
          <ChoiceRow bind={bind || "E"} message={message} color={hintColor} />
        )}
      </div>
    </div>
  );
};

/**
 * Production wrapper : centers the icon on the world point (center of the DUI texture).
 */
const Interaction: React.FC<InteractionProps> = (props) => (
  <div
    style={{
      position:      "fixed",
      left:          "50%",
      top:           "50%",
      transform:     "translate(-50%, -50%)",
      zIndex:        9999,
      opacity:       props.visible ? 1 : 0,
      pointerEvents: "none",
      transition:    "opacity 0.35s ease",
    }}
  >
    <InteractionContent {...props} />
  </div>
);

export default Interaction;
