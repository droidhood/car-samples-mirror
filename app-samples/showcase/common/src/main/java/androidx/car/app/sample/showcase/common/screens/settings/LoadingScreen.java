/*
 * Copyright 2022 The Android Open Source Project
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

package androidx.car.app.sample.showcase.common.screens.settings;

<<<<<<< HEAD
<<<<<<< HEAD
=======
import androidx.annotation.NonNull;
>>>>>>> 7365d9da ([create-pull-request] automated change)
=======
>>>>>>> ff0f88fd ([create-pull-request] automated change)
import androidx.car.app.CarContext;
import androidx.car.app.model.Action;
import androidx.car.app.model.Header;
import androidx.car.app.model.MessageTemplate;
import androidx.car.app.model.Template;
import androidx.car.app.sample.showcase.common.R;

<<<<<<< HEAD
<<<<<<< HEAD
import org.jspecify.annotations.NonNull;

=======
>>>>>>> 7365d9da ([create-pull-request] automated change)
=======
import org.jspecify.annotations.NonNull;

>>>>>>> ff0f88fd ([create-pull-request] automated change)
/** A class that provides a sample template for a loading screen */
public abstract class LoadingScreen {

    private LoadingScreen() {
    }

    /**
    * Returns a sample template to be used for loading a screen
    */
<<<<<<< HEAD
<<<<<<< HEAD
    public static @NonNull Template loadingScreenTemplate(@NonNull CarContext carContext) {
=======
    @NonNull
    public static Template loadingScreenTemplate(@NonNull CarContext carContext) {
>>>>>>> 7365d9da ([create-pull-request] automated change)
=======
    public static @NonNull Template loadingScreenTemplate(@NonNull CarContext carContext) {
>>>>>>> ff0f88fd ([create-pull-request] automated change)
        return new MessageTemplate.Builder(
                carContext.getString(R.string.loading_screen))
                .setLoading(true)
                .setHeader(new Header.Builder().setStartHeaderAction(Action.BACK).build())
                .build();
    }
}
