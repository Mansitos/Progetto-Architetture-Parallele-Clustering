/*
Progetto Programmazione su Architetture Parallele - UNIUD 2021
Christian Cagnoni & Mansi Andrea
*/

#include <stdio.h>
#include <stdlib.h>
#include <random>
#include <iostream>
#include <math.h>
#include <iterator>
#include <omp.h>

#define NOISE -1

std::vector<float*> findNeighbours(float** dataPoints, bool useParallelism, float* dataPoint, float eps, int dim, int length);

std::vector<float*> difference(std::vector<float*> neighbours, float* dataPoint);

void unionVectors(std::vector<float*>* remainder, bool useParallelism, std::vector<float*> neighbours);

float calculateDistancesDB(float* dataPoints, bool useParallelism, float* dataPoint, int dim);

void dbscan(float** dataPoints, int length, int dim, bool useParallelism, std::mt19937 seed) {
	std::uniform_real_distribution<> distrib(0, (sqrt(length) * 2)/10);
	float count = 0;
	const float minPts = 2;
	float eps = distrib(seed);
	for (int point = 0; point < length; point++) {
		float* dataPoint = dataPoints[point];
		if (dataPoint[dim] != 0)
			continue;
		std::vector<float*> neighbours = findNeighbours(dataPoints, useParallelism, dataPoint, eps, dim, length);
		if (neighbours.size() < minPts) {
			dataPoint[dim] = NOISE;
			continue;
		}
		count++;
		dataPoint[dim] = count;
		std::vector<float*> remainder = difference(neighbours, dataPoint);
		for (int i = 0; i < remainder.size(); i++) {
			float* dataPoint = remainder.at(i);
			if (dataPoint[dim] == NOISE)
				dataPoint[dim] = count;
			if (dataPoint[dim] != 0)
				continue;
			dataPoint[dim] = count;
			std::vector<float*> neighboursChild = findNeighbours(dataPoints, useParallelism, dataPoint, eps, dim, length);
			if (neighboursChild.size() >= minPts)
				unionVectors(&remainder, useParallelism, neighboursChild);
		}
	}
}

void unionVectors(std::vector<float*>* remainder, bool useParallelism, std::vector<float*> neighbours) {
	#pragma omp parallel for schedule(static) if(useParallelism)
	for (int i = 0; i < neighbours.size();i++) {
		bool find = false;
		for (int j = 0; j < (*remainder).size(); j++) {
			if ((*remainder).at(j) == neighbours.at(i)) {
				find = true;
			}
		}
		if(!find){
			(*remainder).push_back(neighbours[i]);
		}
	}
}

std::vector<float*> difference(std::vector<float*> neighbours, float* dataPoint) {
	auto it = std::find(neighbours.begin(), neighbours.end(), dataPoint);

	// If element was found
	if (it != neighbours.end())
	{
		int index = it - neighbours.begin();
		neighbours.erase(neighbours.begin() + index);
	}
	return neighbours;
}

std::vector<float*> findNeighbours(float** dataPoints, bool useParallelism, float* dataPoint, float eps, int dim, int length) {
	std::vector<float*> neighbour;
	#pragma omp parallel for schedule(static) if(useParallelism)
	for (int i = 0; i < length; i++) {
		float* actualPoint = dataPoints[i];
		float distance = calculateDistancesDB(actualPoint, useParallelism, dataPoint, dim);
		#pragma omp critical
		if (distance <= eps) {
			neighbour.push_back(actualPoint);
		}
	}
	return neighbour;
}

float calculateDistancesDB(float* dataPoints, bool useParallelism, float* dataPoint, int dim) {
	float distance = 0;
	#pragma omp parallel for schedule(static) if(useParallelism)
	for (int i = 0; i < dim; i++)
		distance += pow(dataPoints[i] - dataPoint[i], 2);
	distance = sqrt(distance);
	return distance;
}