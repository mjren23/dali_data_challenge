library(tidyverse)
library(countrycode)
library(ggthemes)
library(ggrepel)


# Read data ---------------------------------------------------------------

wiid <- read_csv("data/wiid.csv")
worldmap <- read_csv("data/HiResWorldMapWithISO3.csv")


# Heatmap of Gini Index ---------------------------------------------------

# transform data
last_twenty <- wiid %>% 
  filter(year >= 2000) %>% 
  filter(!is.na(gini_reported)) %>% 
  select(c3, gini_reported, country) %>% 
  group_by(country, c3) %>% 
  summarize(avg_gini_last_twenty = mean(gini_reported))

# join with polygon map data
merged_twenty <- left_join(worldmap, last_twenty, by = c("id" = "c3"))

na.value.color <- "darkgray"

# plot 
ggplot(data = merged_twenty) +
  geom_polygon(aes(long, lat, fill = avg_gini_last_twenty, group = group, color = "NA"),
               size = 0.1) +
  scale_fill_gradient(low = "white", high = "steelblue4", na.value = na.value.color,
                      limits = c(26, 67)) +
  scale_color_manual(values = 'black', labels = '') +
  coord_equal() +
  labs(title = "Average Gini coefficient by country, cast 20 years",
       fill = "Gini coefficient",
       color = "No data") +
  theme_void() +
  guides(fill = guide_colorsteps(title.position = "bottom", 
                              title.hjust = 0.5,
                              label.position = "top",
                              show.limits = TRUE,
                              ),
         color = guide_legend(title.position = "bottom",
                              label.position = "top",
                              keywidth = unit(1.2, "cm"),
                              title.hjust = 0.5,
                              override.aes = list(fill = na.value.color),
                              )) +
  theme(legend.position = "bottom",
        legend.key.width = unit(1.5, "cm"),
        legend.spacing.x = unit(1, "cm"))




# Violin plot of median_usd -----------------------------------------------

# transform data
violin <- wiid %>% 
  filter(!is.na(median_usd)) %>% 
  group_by(c3) %>% 
  slice(which.max(year)) 

# get text for labels 
violin_text <- violin %>% 
  group_by(region_un) %>% 
  slice(which.max(median_usd))

# plot
ggplot() +
  geom_violin(data = violin,
              aes(region_un, median_usd, fill = region_un)) +
  geom_text_repel(data = violin_text,
                  aes(region_un, median_usd, label = country),
                  nudge_y = 1000,
                  nudge_x = 0.3,
                  min.segment.length = 0) +
  labs(title = "Distribution of by Region",
       y = "Median USD of survey",
       fill = "Region") +
  theme_few() +
  theme(axis.title.x = element_blank())



# Bottom 50% v.s. top 10% owning resources --------------------------------

# transform data, calculate bottom 50% 
compare_regions <- wiid %>% 
  filter_at(vars(d1:d10), all_vars(!is.na(.))) %>% 
  mutate(bottom_50 = d1 + d2 + d3 + d4 + d5) %>% 
  group_by(year, region_wb) %>% 
  summarize(bottom_50 = mean(bottom_50), top_10 = mean(d10)) %>% 
  pivot_longer(c("bottom_50", "top_10"), names_to = "grouping", values_to = "value")


ggplot(data = compare_regions) +
  geom_smooth(aes(year, value, color = grouping), se = FALSE, span = 0.5) +
  facet_wrap(~region_wb, scales = "free") +
  scale_x_continuous(limits=c(1950, 2021)) +
  scale_y_continuous(limits=c(15, 45)) +
  scale_color_manual(values = c("blue", "red"),
                     labels = c("Bottom 50%", "Top 10%")) +
  theme_few() +
  labs(color = "Group",
       y = "Percentage of resources owned",
       title = "Income inquality since 1960") +
  theme(legend.position = "bottom",
        axis.title.x = element_blank())


# GDP v.s. Gini index -----------------------------------------------------

# transform data, exclude NAs
dots <- wiid %>% 
  filter(!is.na(gdp_ppp_pc_usd2011), !is.na(population), !is.na(gini_reported)) %>% 
  group_by(country, region_un) %>% 
  summarize(gdp = mean(gdp_ppp_pc_usd2011), population = mean(population),
            gini = mean(gini_reported))

# get random sample - but if we want certain countries in there, we can do that
dots_sample <- dots %>% 
  ungroup() %>% 
  mutate(weights = ifelse(country == "United States" | 
                            country == "Luxembourg" |
                            country == "South Africa", 10, 0.2)) %>% 
  group_by(region_un) %>% 
  slice_sample(n = 10, weight_by = weights)

# plot
ggplot(dots_sample) +
  geom_point(aes(gini, gdp, size = population, fill = region_un), alpha = 0.6,
             pch = 21) +
  geom_text_repel(aes(gini, gdp, label = country, color = region_un), size = 2.5,
                  max.overlaps = 15) +
  scale_size_continuous(range = c(2, 12), guide = "none") +
  labs(title = "GDP v.s. Gini Coefficient",
       x = "Gini Coefficient (avg)",
       y = "GDP (2011 USD)") +
  theme_few()

for_export <- ggplot(dots_sample) +
  geom_point(aes(gini, gdp, size = population, fill = region_un), alpha = 0.6,
             pch = 21) +
  geom_text_repel(aes(gini, gdp, label = country, color = region_un), size = 2.5,
                  max.overlaps = 15) +
  scale_size_continuous(range = c(9, 28), guide = "none") +
  labs(title = "GDP v.s. Gini coefficient",
       x = "Gini coefficient (avg)",
       y = "GDP (2011 USD)") +
  theme_few() +
  theme(legend.title = element_blank(),
        text = element_text(size = 16))

for_export 




# Lorenz curve for best, worst,  mid Gini ---------------------------------

# transform data
lorenz <- wiid %>% 
  filter_at(vars(d1:d10), all_vars(!is.na(.))) %>% 
  mutate(zero = 0, one = d1, two = one + d2, three = two + d3,
         four = three + d4, five = four + d5, 
         six = five + d6, seven = six + d7,
         eight = seven + d8, nine = eight + d9, ten = nine + d10) %>% 
  pivot_longer(c("zero", "one", "two", "three", "four", "five", "six", "seven", 
                 "eight", "nine", "ten"), names_to = "decile", values_to = "resources") %>% 
  mutate(decile = case_when(decile == "zero" ~ 0,
                            decile == "one" ~ 10,
                            decile == "two" ~ 20,
                            decile == "three" ~ 30,
                            decile == "four" ~ 40,
                            decile == "five" ~ 50,
                            decile == "six" ~ 60,
                            decile == "seven" ~ 70,
                            decile == "eight" ~ 80,
                            decile == "nine" ~ 90,
                            decile == "ten" ~ 100,
                            )) %>% 
  group_by(country, decile) %>% 
  summarize(resources = mean(resources), gini_reported = mean(gini_reported))

# worst, u.s., best 
bottom <- lorenz %>% 
  filter(!is.na(gini_reported)) %>% 
  group_by(country, decile) %>% 
  summarize(resources = mean(resources), gini = gini_reported) %>% 
  ungroup() %>% 
  arrange(gini) %>% 
  slice_head(n = 11)

top <- lorenz %>% 
  filter(!is.na(gini_reported)) %>% 
  group_by(country, decile) %>% 
  summarize(resources = mean(resources), gini = gini_reported) %>% 
  ungroup() %>% 
  arrange(gini) %>% 
  slice_tail(n = 11)

us <- lorenz %>% 
  filter(!is.na(gini_reported)) %>% 
  filter(country == "United States") 

# join tibbles
lorenz_together <- full_join(bottom, us) %>% 
  full_join(top)

# plot 
ggplot(data = lorenz_together) +
  geom_area(aes(decile, resources, fill = factor(country, 
                                                 levels = c("Czechoslovakia",
                                                           "United States", 
                                                           "South Africa"))),
            position = "identity") +
  geom_point(aes(decile, resources,  fill = country), pch = 21,
             color = "black") +
  geom_abline() +
  coord_cartesian(xlim = c(0, 100), ylim = c(0, 100), expand = FALSE) +
  labs(fill = "Country",
       title = "Lorenz curve for highest and lowest Gini index, compared to US",
       x = "Population decile",
       y = "Percent of resources owned") +
  theme_few() +
  theme(text = element_text(size = 16))





