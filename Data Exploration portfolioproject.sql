SELECT * from covid_deaths
ORDER BY 3,4;

-- Select the data that we are going to be using

SELECT location, date, total_cases, new_cases, total_deaths, population
from covid_deaths
order by 1,2;

-- Looking at total cases vs total deaths
-- shows the likelihood of dying if you contract covid in your country
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 as 'Mortality Rate (%)'
from covid_deaths
where location like '%states'
order by 1,2;

-- looking at the total cases vs the population
-- shows the likelihood of contracting covid in your country/percentage of population that got covid
SELECT location, max(population), max(total_cases), max((total_cases/population)*100) as Prevalence
from covid_deaths
where location = 'kenya'
group by location
order by 1,2;

-- looking at countries with highest infection rate compared to population
SELECT Location, Population, max(total_cases) as 'Highest Infection Count', max((total_cases/population)*100) as 'Infection Rate (%)'
from covid_deaths
GROUP BY location, population
ORDER BY 4 desc;

-- change data type of column total_deaths to integer for the next query to work
UPDATE covid_deaths
SET total_deaths = 0
WHERE total_deaths = '';

ALTER TABLE covid_deaths
MODIFY COLUMN total_deaths INT;

-- showing countries with the highest death count per population
select Location, Population, max(total_deaths), max((total_deaths/population)*100) as 'Mortality Rate (%)'
from covid_deaths
GROUP BY location, population
ORDER BY 4 DESC;

SELECT DISTINCT location
from covid_deaths;

-- display the data by continent
-- change population data type
alter table covid_deaths
modify column population BIGINT;

-- highest death count
select location, population, max(total_deaths) as 'Total Deaths', max((total_deaths/population)*100) as 'Mortality Rate (%)'
from covid_deaths
where continent = ''
GROUP BY location, population
ORDER BY 4 DESC;

-- Global Numbers
-- worldwide
SELECT location, sum(new_cases) as Total_cases_ww, sum(new_deaths) as Total_deaths_ww, (sum(new_deaths)/sum(new_cases))*100
from covid_deaths
where location = 'World'
group by location;

SELECT sum(new_cases) as Total_cases_ww, sum(new_deaths) as Total_deaths_ww, (sum(new_deaths)/sum(new_cases))*100 as 'Mortality Rate (%)'
from covid_deaths
where iso_code not like 'owid%';

-- based on date
SELECT date, sum(new_cases) as Total_cases_ww, sum(new_deaths) as Total_deaths_ww, (sum(new_deaths)/sum(new_cases))*100 as 'Mortality Rate (%)'
from covid_deaths
where iso_code not like 'owid%'
group by date
order by 1;

-- WORKING WITH THE VACCINATIONS TABLE
SELECT * from covid_vaccinations;

delete from covid_vaccinations;

-- view only relevant columns
SELECT continent, location, date, total_vaccinations, people_vaccinated, people_fully_vaccinated 
from covid_vaccinations
where location <> 'world'
order by 4 desc;

-- total number of vaccinations
	-- change data type to facilitate correct query results
update covid_vaccinations set total_vaccinations = 0 where total_vaccinations = '';
update covid_vaccinations set people_vaccinated = 0 where people_vaccinated = '';
update covid_vaccinations set people_fully_vaccinated = 0 where people_fully_vaccinated = '';

ROLLBACK;

alter table covid_vaccinations
modify column total_vaccinations BIGINT,
modify column people_vaccinated BIGINT,
modify column people_fully_vaccinated BIGINT,
modify column total_boosters BIGINT;

	-- based on country
SELECT location, max(total_vaccinations), max(people_vaccinated), max(people_fully_vaccinated), ((max(people_vaccinated)-max(people_fully_vaccinated))/max(people_vaccinated))*100 as 'Attrition Rate (%)'
from covid_vaccinations
where continent <> ''
group by location
order by 2 desc;

	-- based on continent
SELECT location, max(total_vaccinations), max(people_vaccinated), max(people_fully_vaccinated), ((max(people_vaccinated)-max(people_fully_vaccinated))/max(people_vaccinated))*100 as 'Attrition Rate (%)' 
from covid_vaccinations
where continent = '' and location not like '%income'
group by location
order by 2 desc;

-- looking at total population vs people vaccinated per country
SELECT cd.location, max(cd.population), max(cv.people_vaccinated), (max(cv.people_vaccinated)/max(cd.population))*100 as 'Vaccination Coverage (%)'
from covid_deaths cd
join covid_vaccinations cv
where cd.location = cv.location and cd.date = cv.date and cd.continent <> ''
group by cd.location
order by 4 desc
;

-- looking at total population vs people vaccinated per continent
SELECT cd.location, max(cd.population), max(cv.people_vaccinated), (max(cv.people_vaccinated)/max(cd.population))*100 as 'Vaccination Coverage (%)'
from covid_deaths cd
join covid_vaccinations cv
where cd.location = cv.location and cd.date = cv.date and cd.continent = ''
group by cd.location
order by 4 desc
;

update covid_vaccinations
set new_vaccinations = 0
where new_vaccinations = '';

-- looking at total population vs vaccinations with rolling totals
SELECT continent, location, date, population, new_vaccinations, RollingCount, RollingCount/population*100
FROM (SELECT cd.continent, cd.location, cd.date, population, new_vaccinations, sum(new_vaccinations) over (PARTITION BY cd.location ORDER BY cd.date) as RollingCount
from covid_deaths cd
        JOIN covid_vaccinations cv
WHERE cd.location = cv.location
        AND cd.date = cv.date
        AND cd.continent <> ''
ORDER BY 2,3) tempt
;

	-- using CTE
WITH PopvsVax (continent, location, date, population, newvaccinations, RollingPeopleVaccinated) as (
SELECT cd.continent, cd.location, cd.date, population, new_vaccinations, sum(new_vaccinations) over (PARTITION BY cd.location ORDER BY cd.date) as RollingCount
from covid_deaths cd
        JOIN covid_vaccinations cv
WHERE cd.location = cv.location
        AND cd.date = cv.date
        AND cd.continent <> ''
ORDER BY 2,3)
SELECT *, rollingpeoplevaccinated/population*100 from popvsvax;

	-- using a temp table(mysql uses "temporary" clause instead of #)
DROP TABLE if exists PopVsVacc;
CREATE temporary TABLE PopVsVacc (
continent varchar(255),
location varchar(255),
date datetime,
population bigint,
newvacc int,
cumvpplvacc int,
cumvpplvaccperc numeric);
alter table popvsvacc
modify column cumvpplvacc bigint;
INSERT INTO PopVsVacc
SELECT cd.continent, cd.location, cd.date, population, new_vaccinations, sum(new_vaccinations) over (PARTITION BY cd.location ORDER BY cd.date) as RollingCount
from covid_deaths cd
        JOIN covid_vaccinations cv
WHERE cd.location = cv.location
        AND cd.date = cv.date
        AND cd.continent <> ''
ORDER BY 2,3
;

select *, cumvpplvacc/population*100 as PercentageVaccination from popvsvacc;

-- compare vaccination status with mortality rate (use statistical significance to check for significance of intervention)
	-- based on country 
SELECT cv.location, max(population), max(people_vaccinated), sum(new_deaths) as Total_deaths_ww
from covid_vaccinations cv
join covid_deaths cd on cv.location = cd.location and cv.date = cd.date and cv.continent <> ''
group by location
;

-- create view to store data for later visualizations
CREATE VIEW PercentPopulationVaccinated as 
SELECT cd.continent, cd.location, cd.date, population, new_vaccinations, sum(new_vaccinations) over (PARTITION BY cd.location ORDER BY cd.date) as RollingCount
from covidpercentpopulationvaccinated_deaths cd
        JOIN covid_vaccinations cv
WHERE cd.location = cv.location
        AND cd.date = cv.date
        AND cd.continent <> ''
ORDER BY 2,3
;