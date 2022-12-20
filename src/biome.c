#include "SPBiome.h"

void spBiomeGetTagsForPoint(SPBiomeThreadState *threadState,
                            uint16_t *tagsOut,
                            int *tagCountOut,
                            SPVec3 pointNormal,
                            SPVec3 noiseLoc,
                            double altitude,
                            double steepness,
                            double riverDistance,
                            double temperatureSummer,
                            double temperatureWinter,
                            double rainfallSummer,
                            double rainfallWinter)
{
    *tagCountOut = 0;
    *tagsOut = 0;
}