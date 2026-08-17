// Auto-imported flower icons keyed by group name (matches private_groups.name in DB).
// Used by PrivateGroupsSection and AvailableGroupsSection.
import rose from './rose.jpg';
import lily from './lily.jpg';
import jasmine from './jasmine.jpg';
import orchid from './orchid.jpg';
import sunflower from './sunflower.jpg';
import tulip from './tulip.jpg';
import lotus from './lotus.jpg';
import daisy from './daisy.jpg';
import lavender from './lavender.jpg';
import marigold from './marigold.jpg';
import hibiscus from './hibiscus.jpg';
import magnolia from './magnolia.jpg';
import peony from './peony.jpg';
import camellia from './camellia.jpg';
import iris from './iris.jpg';
import poppy from './poppy.jpg';
import bluebell from './bluebell.jpg';
import carnation from './carnation.jpg';
import chrysanthemum from './chrysanthemum.jpg';
import dahlia from './dahlia.jpg';
import freesia from './freesia.jpg';
import gardenia from './gardenia.jpg';
import geranium from './geranium.jpg';
import hyacinth from './hyacinth.jpg';
import petunia from './petunia.jpg';
import primrose from './primrose.jpg';
import rhododendron from './rhododendron.jpg';
import snowdrop from './snowdrop.jpg';
import verbena from './verbena.jpg';
import violet from './violet.jpg';
import zinnia from './zinnia.jpg';
import anemone from './anemone.jpg';
import azalea from './azalea.jpg';
import begonia from './begonia.jpg';
import buttercup from './buttercup.jpg';
import clematis from './clematis.jpg';
import cosmos from './cosmos.jpg';
import dandelion from './dandelion.jpg';
import foxglove from './foxglove.jpg';
import heather from './heather.jpg';

export const FLOWER_IMAGES: Record<string, string> = {
  Rose: rose, Lily: lily, Jasmine: jasmine, Orchid: orchid, Sunflower: sunflower,
  Tulip: tulip, Lotus: lotus, Daisy: daisy, Lavender: lavender, Marigold: marigold,
  Hibiscus: hibiscus, Magnolia: magnolia, Peony: peony, Camellia: camellia, Iris: iris,
  Poppy: poppy, Bluebell: bluebell, Carnation: carnation, Chrysanthemum: chrysanthemum, Dahlia: dahlia,
  Freesia: freesia, Gardenia: gardenia, Geranium: geranium, Hyacinth: hyacinth, Petunia: petunia,
  Primrose: primrose, Rhododendron: rhododendron, Snowdrop: snowdrop, Verbena: verbena, Violet: violet,
  Zinnia: zinnia, Anemone: anemone, Azalea: azalea, Begonia: begonia, Buttercup: buttercup,
  Clematis: clematis, Cosmos: cosmos, Dandelion: dandelion, Foxglove: foxglove, Heather: heather,
};

/** Fallback to rose if name is unknown */
export const getFlowerImage = (name: string): string => FLOWER_IMAGES[name] || rose;
