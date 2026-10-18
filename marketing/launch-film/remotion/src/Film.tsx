import React from 'react';
import {AbsoluteFill, Audio, staticFile, useCurrentFrame} from 'remotion';
import {FPS, ip} from './lib/theme';
import {Backdrop, Grain, SampleNote} from './lib/Atmos';
import {AloneScene, NumberScene, OpenScene} from './scenes/Opening';
import {RevealScene} from './scenes/Reveal';
import {CaptureScene} from './scenes/Capture';
import {ClubScene, FeedScene, PBScene, RankingsScene} from './scenes/Features';
import {EndScene} from './scenes/End';

export type FilmProps = {bgm: boolean};

/** 90 s launch film. Every time below is in seconds and matches remotion/src/timeline.json and voice/timeline.json. */
export const Film: React.FC<FilmProps> = ({bgm}) => {
  const t = useCurrentFrame() / FPS;
  // the room is darkest in the problem section and warms from the reveal on
  const blue = ip(t, [0, 6], [0.03, 0.06]) * ip(t, [14, 18], [1, 0.4]) + ip(t, [27, 31], [0, 0.07]);
  const lilac = ip(t, [27, 31], [0, 0.05]) * ip(t, [88.5, 90], [1, 0]);
  const note = Math.min(ip(t, [32.4, 33.2], [0, 1]), ip(t, [82.0, 82.6], [1, 0]));
  return (
    <AbsoluteFill>
      <Backdrop blue={blue} lilac={lilac} drift={t / 90} />
      <OpenScene />
      <NumberScene />
      <AloneScene />
      <RevealScene />
      <CaptureScene />
      <FeedScene />
      <PBScene />
      <RankingsScene />
      <ClubScene />
      <EndScene />
      <SampleNote opacity={note} />
      <Grain amount={0.06} />
      <Audio src={staticFile(bgm ? 'audio/mix.wav' : 'audio/mix-nomusic.wav')} />
    </AbsoluteFill>
  );
};
