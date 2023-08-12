#!/bin/bash

# https://backstage.io/docs/features/search/getting-started/
# https://github.com/backstage/backstage/tree/master/plugins/stack-overflow

backstage_app_name=my-backstage

cd ~/backstage/plugins/stack-overflow

if test -f "app-config.yaml"; then
  rm app-config.yaml
fi

cat <<EOF | tee app-config.yaml
stackoverflow:
  baseUrl: https://api.stackexchange.com/2.2
EOF

cd ~/${backstage_app_name}

# CONFIGURE THE SEARCH PAGE
if test -f ~/${backstage_app_name}/packages/app/src/components/search/SearchPage.tsx; then
  rm ~/${backstage_app_name}/packages/app/src/components/search/SearchPage.tsx
fi

cat <<EOF | tee ~/${backstage_app_name}/packages/app/src/components/search/SearchPage.tsx
import React from 'react';
import { Content, Header, Page } from '@backstage/core-components';
import { Grid, List, Card, CardContent } from '@material-ui/core';
import {
  SearchBar,
  SearchResult,
  DefaultResultListItem,
  SearchFilter,
} from '@backstage/plugin-search-react';
import { CatalogSearchResultListItem } from '@backstage/plugin-catalog';

export const searchPage = (
  <Page themeId="home">
    <Header title="Search" />
    <Content>
      <Grid container direction="row">
        <Grid item xs={12}>
          <SearchBar />
        </Grid>
        <Grid item xs={3}>
          <Card>
            <CardContent>
              <SearchFilter.Select
                name="kind"
                values={['Component', 'Template']}
              />
            </CardContent>
            <CardContent>
              <SearchFilter.Checkbox
                name="lifecycle"
                values={['experimental', 'production']}
              />
            </CardContent>
          </Card>
        </Grid>
        <Grid item xs={9}>
          <SearchResult>
            {({ results }) => (
              <List>
                {results.map(result => {
                  switch (result.type) {
                    case 'software-catalog':
                      return (
                        <CatalogSearchResultListItem
                          key={result.document.location}
                          result={result.document}
                          highlight={result.highlight}
                        />
                      );
                    case 'stack-overflow':
                      return (
                        <StackOverflowSearchResultListItem
                          key={document.location}
                          result={document}
                        />
                      );
                    default:
                      return (
                        <DefaultResultListItem
                          key={result.document.location}
                          result={result.document}
                          highlight={result.highlight}
                        />
                      );
                  }
                })}
              </List>
            )}
          </SearchResult>
        </Grid>
      </Grid>
    </Content>
  </Page>
);
EOF


