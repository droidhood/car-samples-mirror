/*
 * Copyright (C) 2021 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package androidx.car.app.sample.showcase.common.screens.navigationdemos;

<<<<<<< HEAD
=======
import androidx.annotation.NonNull;
>>>>>>> 7365d9da ([create-pull-request] automated change)
import androidx.car.app.CarContext;
import androidx.car.app.Screen;
import androidx.car.app.model.Action;
import androidx.car.app.model.ActionStrip;
import androidx.car.app.model.Template;
import androidx.car.app.navigation.model.NavigationTemplate;
import androidx.car.app.sample.showcase.common.R;

<<<<<<< HEAD
import org.jspecify.annotations.NonNull;

=======
>>>>>>> 7365d9da ([create-pull-request] automated change)
/** Simple demo of how to present a navigation screen with only a map. */
public final class NavigationMapOnlyScreen extends Screen {

    public NavigationMapOnlyScreen(@NonNull CarContext carContext) {
        super(carContext);
    }

<<<<<<< HEAD
    @Override
    public @NonNull Template onGetTemplate() {
=======
    @NonNull
    @Override
    public Template onGetTemplate() {
>>>>>>> 7365d9da ([create-pull-request] automated change)
        ActionStrip actionStrip =
                new ActionStrip.Builder()
                        .addAction(
                                new Action.Builder()
                                        .setTitle(getCarContext().getString(
                                                R.string.back_caps_action_title))
                                        .setOnClickListener(this::finish)
                                        .build())
                        .build();

        return new NavigationTemplate.Builder().setActionStrip(actionStrip).build();
    }
}
