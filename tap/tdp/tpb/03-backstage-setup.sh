#!/bin/bash

backstage_app_name=my-backstage

cd ~/${backstage_app_name}


# SETUP HOME PAGE
# https://backstage.io/docs/getting-started/homepage/
# From your Backstage root directory
yarn add --cwd packages/app @backstage/plugin-home

if [ -d "~/${backstage_app_name}/packages/app/src/components/home" ] 
then
  if test -f ~/${backstage_app_name}/packages/app/src/components/home/HomePage.tsx; then
    rm ~/${backstage_app_name}/packages/app/src/components/home/HomePage.tsx
  fi
else
  mkdir ~/${backstage_app_name}/packages/app/src/components/home
fi

cat <<EOF | tee ~/${backstage_app_name}/packages/app/src/components/home/HomePage.tsx
import React from 'react';

export const HomePage = () => (
  <h1>Welcome to Backstage!</h1>
);
EOF

# VIM APP.TSX AND UPDATE THE FOLLOWING SECTIONS,
# OR JUST OVERWRITE THE WHOLE FILE WITH THE CONTENTS BELOW
# vim ~/${backstage_app_name}/packages/app/src/App.tsx

# import { HomepageCompositionRoot } from '@backstage/plugin-home';
# import { HomePage } from './components/home/HomePage';

# const routes = (
#   <FlatRoutes>
#     # <Navigate key="/" to="catalog" /> REPLACE THIS LINE
#     <Route path="/" element={<HomepageCompositionRoot />}>
#       <HomePage />
#     </Route>
#   </FlatRoutes>
# );

if test -f ~/${backstage_app_name}/packages/app/src/App.tsx; then
  rm ~/${backstage_app_name}/packages/app/src/App.tsx
fi

cat <<EOF | tee ~/${backstage_app_name}/packages/app/src/App.tsx
import React from 'react';
import { Navigate, Route } from 'react-router-dom';
import { apiDocsPlugin, ApiExplorerPage } from '@backstage/plugin-api-docs';
import {
  CatalogEntityPage,
  CatalogIndexPage,
  catalogPlugin,
} from '@backstage/plugin-catalog';
import {
  CatalogImportPage,
  catalogImportPlugin,
} from '@backstage/plugin-catalog-import';
import { ScaffolderPage, scaffolderPlugin } from '@backstage/plugin-scaffolder';
import { orgPlugin } from '@backstage/plugin-org';
import { SearchPage } from '@backstage/plugin-search';
import { TechRadarPage } from '@backstage/plugin-tech-radar';
import {
  TechDocsIndexPage,
  techdocsPlugin,
  TechDocsReaderPage,
} from '@backstage/plugin-techdocs';
import { TechDocsAddons } from '@backstage/plugin-techdocs-react';
import { ReportIssue } from '@backstage/plugin-techdocs-module-addons-contrib';
import { UserSettingsPage } from '@backstage/plugin-user-settings';
import { apis } from './apis';
import { entityPage } from './components/catalog/EntityPage';
import { searchPage } from './components/search/SearchPage';
import { Root } from './components/Root';

import { AlertDisplay, OAuthRequestDialog } from '@backstage/core-components';
import { createApp } from '@backstage/app-defaults';
import { AppRouter, FlatRoutes } from '@backstage/core-app-api';
import { CatalogGraphPage } from '@backstage/plugin-catalog-graph';
import { RequirePermission } from '@backstage/plugin-permission-react';
import { catalogEntityCreatePermission } from '@backstage/plugin-catalog-common/alpha';
import { HomepageCompositionRoot } from '@backstage/plugin-home';
import { HomePage } from './components/home/HomePage';

const app = createApp({
  apis,
  bindRoutes({ bind }) {
    bind(catalogPlugin.externalRoutes, {
      createComponent: scaffolderPlugin.routes.root,
      viewTechDoc: techdocsPlugin.routes.docRoot,
      createFromTemplate: scaffolderPlugin.routes.selectedTemplate,
    });
    bind(apiDocsPlugin.externalRoutes, {
      registerApi: catalogImportPlugin.routes.importPage,
    });
    bind(scaffolderPlugin.externalRoutes, {
      registerComponent: catalogImportPlugin.routes.importPage,
      viewTechDoc: techdocsPlugin.routes.docRoot,
    });
    bind(orgPlugin.externalRoutes, {
      catalogIndex: catalogPlugin.routes.catalogIndex,
    });
  },
});

const routes = (
  <FlatRoutes>
    <Route path="/" element={<HomepageCompositionRoot />}>
      <HomePage />
    </Route>
    <Route path="/catalog" element={<CatalogIndexPage />} />
    <Route
      path="/catalog/:namespace/:kind/:name"
      element={<CatalogEntityPage />}
    >
      {entityPage}
    </Route>
    <Route path="/docs" element={<TechDocsIndexPage />} />
    <Route
      path="/docs/:namespace/:kind/:name/*"
      element={<TechDocsReaderPage />}
    >
      <TechDocsAddons>
        <ReportIssue />
      </TechDocsAddons>
    </Route>
    <Route path="/create" element={<ScaffolderPage />} />
    <Route path="/api-docs" element={<ApiExplorerPage />} />
    <Route
      path="/tech-radar"
      element={<TechRadarPage width={1500} height={800} />}
    />
    <Route
      path="/catalog-import"
      element={
        <RequirePermission permission={catalogEntityCreatePermission}>
          <CatalogImportPage />
        </RequirePermission>
      }
    />
    <Route path="/search" element={<SearchPage />}>
      {searchPage}
    </Route>
    <Route path="/settings" element={<UserSettingsPage />} />
    <Route path="/catalog-graph" element={<CatalogGraphPage />} />
  </FlatRoutes>
);

export default app.createRoot(
  <>
    <AlertDisplay />
    <OAuthRequestDialog />
    <AppRouter>
      <Root>{routes}</Root>
    </AppRouter>
  </>,
);
EOF

# DON'T DELETE AND RECREATE THIS FILE - IT WILL NOT WORK - JUST MANUALLY EDIT IT
# if test -f ~/${backstage_app_name}/packages/app/src/components/Root/Root.tsx; then
#   rm ~/${backstage_app_name}/packages/app/src/components/Root/Root.tsx
# fi

# import CategoryIcon from '@material-ui/icons/Category';

# <SidebarItem icon={HomeIcon} to="/" text="Home" />
# <SidebarItem icon={CategoryIcon} to="catalog" text="Catalog" />

vim ~/${backstage_app_name}/packages/app/src/components/Root/Root.tsx

# cat <<EOF | tee ~/${backstage_app_name}/packages/app/src/components/Root/Root.tsx
# import React, { PropsWithChildren } from 'react';
# import { makeStyles } from '@material-ui/core';
# import HomeIcon from '@material-ui/icons/Home';
# import ExtensionIcon from '@material-ui/icons/Extension';
# import MapIcon from '@material-ui/icons/MyLocation';
# import LibraryBooks from '@material-ui/icons/LibraryBooks';
# import CreateComponentIcon from '@material-ui/icons/AddCircleOutline';
# import LogoFull from './LogoFull';
# import LogoIcon from './LogoIcon';
# import {
#   Settings as SidebarSettings,
#   UserSettingsSignInAvatar,
# } from '@backstage/plugin-user-settings';
# import { SidebarSearchModal } from '@backstage/plugin-search';
# import {
#   Sidebar,
#   sidebarConfig,
#   SidebarDivider,
#   SidebarGroup,
#   SidebarItem,
#   SidebarPage,
#   SidebarScrollWrapper,
#   SidebarSpace,
#   useSidebarOpenState,
#   Link,
# } from '@backstage/core-components';
# import MenuIcon from '@material-ui/icons/Menu';
# import SearchIcon from '@material-ui/icons/Search';
# import CategoryIcon from '@material-ui/icons/Category';

# const useSidebarLogoStyles = makeStyles({
#   root: {
#     width: sidebarConfig.drawerWidthClosed,
#     height: 3 * sidebarConfig.logoHeight,
#     display: 'flex',
#     flexFlow: 'row nowrap',
#     alignItems: 'center',
#     marginBottom: -14,
#   },
#   link: {
#     width: sidebarConfig.drawerWidthClosed,
#     marginLeft: 24,
#   },
# });

# const SidebarLogo = () => {
#   const classes = useSidebarLogoStyles();
#   const { isOpen } = useSidebarOpenState();

#   return (
#     <div className={classes.root}>
#       <Link to="/" underline="none" className={classes.link} aria-label="Home">
#         {isOpen ? <LogoFull /> : <LogoIcon />}
#       </Link>
#     </div>
#   );
# };

# export const Root = ({ children }: PropsWithChildren<{}>) => (
#   <SidebarPage>
#     <Sidebar>
#       <SidebarLogo />
#       <SidebarGroup label="Search" icon={<SearchIcon />} to="/search">
#         <SidebarSearchModal />
#       </SidebarGroup>
#       <SidebarDivider />
#       <SidebarGroup label="Menu" icon={<MenuIcon />}>
#         {/* Global nav, not org-specific */}
#         <SidebarItem icon={HomeIcon} to="/" text="Home" />
#         <SidebarItem icon={CategoryIcon} to="catalog" text="Catalog" />
#         <SidebarItem icon={ExtensionIcon} to="api-docs" text="APIs" />
#         <SidebarItem icon={LibraryBooks} to="docs" text="Docs" />
#         <SidebarItem icon={CreateComponentIcon} to="create" text="Create..." />
#         {/* End global nav */}
#         <SidebarDivider />
#         <SidebarScrollWrapper>
#           <SidebarItem icon={MapIcon} to="tech-radar" text="Tech Radar" />
#         </SidebarScrollWrapper>
#       </SidebarGroup>
#       <SidebarSpace />
#       <SidebarDivider />
#       <SidebarGroup
#         label="Settings"
#         icon={<UserSettingsSignInAvatar />}
#         to="/settings"
#       >
#         <SidebarSettings />
#       </SidebarGroup>
#     </Sidebar>
#     {children}
#   </SidebarPage>
# );
# EOF

